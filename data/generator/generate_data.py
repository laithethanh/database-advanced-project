"""Deterministic large dataset generator skeleton.

The implementation will use a fixed seed and parameterized bulk inserts.
Target: >= 100,000 orders.
"""

import argparse
import random


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--orders", type=int, default=100_000)
    parser.add_argument("--seed", type=int, default=20261003)
    args = parser.parse_args()
    random.seed(args.seed)
    print(f"dataset generator placeholder: orders={args.orders}, seed={args.seed}")


if __name__ == "__main__":
    main()
