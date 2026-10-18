# Object database model

`ecommerce.odl` specifies six persistent classes: Account, Customer, Seller, Product, ProductVariant and Order. `OrderLine` is a value type held in an ordered collection, not a persistent class. Every persistent object has an implementation-managed OID; `email`, `sku` and `orderNumber` are business identifiers, not OIDs. `Customer` and `Seller` inherit shared identity fields from `Account`; collections express inverse associations and `Order.items` deliberately uses an ordered list.

The relational mapping used for the demonstration is: `Account→account`, `Customer→customer`, `Seller→seller`, `Product→product`, `ProductVariant→product_variant`, `Order→orders`, `OrderLine→order_item`; object links map to existing FK columns. `Order.total()` maps to `grand_total`; `OrderLine.lineTotal` maps to snapshot `line_total`.

For execution evidence, import the model into ObjectDB (JPA) or translate each OQL in `../queries/ecommerce.oql` to JPQL. This repository does not claim ObjectDB results without an ObjectDB runtime.
