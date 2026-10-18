"""Deterministic MySQL benchmark-data generator (default: 100,000 orders).

Run against an empty database after scripts 01, 02 and 05. It deliberately
does not invoke checkout: bulk history is seeded directly while preserving the
same FK, total and lifecycle invariants enforced by triggers.
"""
from __future__ import annotations
import argparse, os, random
from datetime import datetime, timedelta
from decimal import Decimal
import pymysql
from faker import Faker


def connect():
    return pymysql.connect(host=os.environ['DB_HOST'], port=int(os.getenv('DB_PORT','3306')), user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD'], database=os.getenv('DB_NAME','ecommerce_advanced'), charset='utf8mb4', autocommit=False)


def chunks(rows, size):
    for start in range(0, len(rows), size): yield rows[start:start+size]


def scalar(cur, sql, args=()):
    cur.execute(sql,args); return cur.fetchone()[0]


def main():
    p=argparse.ArgumentParser(); p.add_argument('--orders',type=int,default=100_000); p.add_argument('--customers',type=int,default=10_000)
    p.add_argument('--sellers',type=int,default=100); p.add_argument('--products',type=int,default=1_000); p.add_argument('--seed',type=int,default=20261003)
    p.add_argument('--chunk-size',type=int,default=1_000); args=p.parse_args()
    if min(args.orders,args.customers,args.sellers,args.products,args.chunk_size) <= 0: p.error('all sizes must be positive')
    rng=random.Random(args.seed); fake=Faker('en_US'); Faker.seed(args.seed)
    db=connect()
    try:
      with db.cursor() as cur:
        if scalar(cur,'SELECT COUNT(*) FROM orders') != 0: raise RuntimeError('target database already contains orders; use a fresh benchmark database')
        warehouses=[]; cur.execute("SELECT warehouse_id FROM warehouse WHERE status='ACTIVE' ORDER BY warehouse_id"); warehouses=[r[0] for r in cur.fetchall()]
        if not warehouses: raise RuntimeError('schema warehouse seed is missing')
        # accounts and their customer/seller subtypes
        accounts=[]
        for i in range(args.customers): accounts.append((f'bench.customer.{i:06d}@example.test','benchmark-hash',fake.name(),f'09{i:08d}'[-10:]))
        for i in range(args.sellers): accounts.append((f'bench.seller.{i:05d}@example.test','benchmark-hash',f'Bench Seller {i:04d}',f'08{i:08d}'[-10:]))
        cur.executemany('INSERT INTO account(email,password_hash,full_name,phone) VALUES(%s,%s,%s,%s)',accounts)
        cur.execute("SELECT account_id,email FROM account WHERE email LIKE 'bench.customer.%' ORDER BY account_id"); customers=[r[0] for r in cur.fetchall()]
        cur.execute("SELECT account_id,email FROM account WHERE email LIKE 'bench.seller.%' ORDER BY account_id"); sellers=[r[0] for r in cur.fetchall()]
        cur.executemany('INSERT INTO customer(account_id,customer_code) VALUES(%s,%s)',[(x,f'BC{x:08d}') for x in customers])
        cur.executemany("INSERT INTO seller(account_id,seller_code,shop_name,shop_status) VALUES(%s,%s,%s,'ACTIVE')",[(x,f'BS{x:08d}',f'Benchmark shop {x}') for x in sellers])
        # Three-level category tree, created before products because product trigger requires ACTIVE category.
        cur.executemany("INSERT INTO category(name,slug,status) VALUES(%s,%s,'ACTIVE')",[(f'Benchmark root {i}',f'bench-root-{i}') for i in range(10)])
        cur.execute("SELECT category_id FROM category WHERE slug LIKE 'bench-root-%' ORDER BY category_id"); roots=[r[0] for r in cur.fetchall()]
        cur.executemany("INSERT INTO category(parent_category_id,name,slug,status) VALUES(%s,%s,%s,'ACTIVE')",[(roots[i%len(roots)],f'Benchmark leaf {i}',f'bench-leaf-{i}') for i in range(100)])
        cur.execute("SELECT category_id FROM category WHERE slug LIKE 'bench-leaf-%' ORDER BY category_id"); categories=[r[0] for r in cur.fetchall()]
        products=[(categories[i%len(categories)],f'Benchmark product {i:05d}',f'bench-product-{i:05d}','Generated reproducible benchmark product',f'Brand {i%20}','ACTIVE') for i in range(args.products)]
        cur.executemany('INSERT INTO product(category_id,name,slug,description,brand,status) VALUES(%s,%s,%s,%s,%s,%s)',products)
        cur.execute("SELECT product_id,name FROM product WHERE slug LIKE 'bench-product-%' ORDER BY product_id"); product_rows=cur.fetchall()
        variants=[]
        for i,(product_id,_) in enumerate(product_rows):
          for color,size in [('Black','M'),('Blue','L')]: variants.append((warehouses[i%len(warehouses)],product_id,f'BSKU-{i:05d}-{color[0]}',color,size,Decimal(rng.randrange(10000,500000)),'ACTIVE'))
        cur.executemany('INSERT INTO product_variant(warehouse_id,product_id,sku,color,size,price,warehouse_quantity,status) VALUES(%s,%s,%s,%s,%s,%s,100000,%s)',variants)
        cur.execute("SELECT variant_id,product_id,sku,price FROM product_variant WHERE sku LIKE 'BSKU-%' ORDER BY variant_id"); variant_rows=cur.fetchall()
        # Each variant has several shops; sufficient stock makes the generated completed history valid.
        inv=[(seller_id,variant_id,100000,0,100) for variant_id,_,_,_ in variant_rows for seller_id in rng.sample(sellers,min(3,len(sellers)))]
        cur.executemany('INSERT INTO inventory(seller_id,variant_id,quantity_on_hand,reserved_quantity,reorder_level) VALUES(%s,%s,%s,%s,%s)',inv)
        db.commit()
        inventory_by_variant={}
        for seller_id,variant_id,*_ in inv: inventory_by_variant.setdefault(variant_id,[]).append(seller_id)
        variant_info={r[0]:r for r in variant_rows}; base=datetime(2025,1,1)
        for batch_no,start in enumerate(range(0,args.orders,args.chunk_size),1):
          count=min(args.chunk_size,args.orders-start); orders=[]
          for n in range(start,start+count):
            customer_id=rng.choice(customers); created=base+timedelta(minutes=rng.randrange(0,525600))
            orders.append((f'BORD-{args.seed}-{n:09d}',customer_id,'PENDING_PAYMENT',f'Recipient {customer_id}','0900000000','Benchmark address',Decimal('15000'),created,created))
          cur.executemany("INSERT INTO orders(order_number,customer_id,status,recipient_name,recipient_phone,shipping_address,subtotal,discount_total,shipping_fee,grand_total,placed_at,created_at) VALUES(%s,%s,%s,%s,%s,%s,0,0,%s,%s,%s,%s)",[(a,b,c,d,e,f,g,g,h,i) for a,b,c,d,e,f,g,h,i in orders])
          first_id=cur.lastrowid; item_rows=[]
          for offset in range(count):
            order_id=first_id+offset
            for variant_id in rng.sample(list(variant_info),rng.randint(1,3)):
              _,product_id,sku,price=variant_info[variant_id]; seller_id=rng.choice(inventory_by_variant[variant_id]); qty=rng.randint(1,3)
              item_rows.append((order_id,seller_id,variant_id,f'Product {product_id}',sku,price,qty,0,price*qty))
          cur.executemany('INSERT INTO order_item(order_id,seller_id,variant_id,product_name_snapshot,sku_snapshot,unit_price,quantity,line_discount,line_total) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)',item_rows)
          cur.execute('SELECT order_id,grand_total FROM orders WHERE order_id BETWEEN %s AND %s',(first_id,first_id+count-1)); payments=[(oid,'BENCHMARK',f'PAY-{oid}',amount,'SUCCESS') for oid,amount in cur.fetchall()]
          cur.executemany("INSERT INTO payment(order_id,provider,transaction_ref,amount,status,paid_at) VALUES(%s,%s,%s,%s,%s,UTC_TIMESTAMP())",payments)
          cur.execute("UPDATE orders SET status='PAID' WHERE order_id BETWEEN %s AND %s",(first_id,first_id+count-1)); db.commit()
          print(f'committed batch {batch_no}: {start+count}/{args.orders} orders')
    except Exception:
      db.rollback(); raise
    finally: db.close()


if __name__=='__main__': main()
