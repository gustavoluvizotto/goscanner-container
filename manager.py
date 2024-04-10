#!/usr/bin/env python3
"""
Responsible to
"""
__author__ = "Gustavo Luvizotto Cesar"
__email__ = "g.luvizottocesar@utwente.nl"

import argparse

from retrieve_allowlist import retrieve_allowlist
from transfer_to_objstore import transfer_to_objstore


def main(args):
    if args.upload:
        transfer_to_objstore(args.output_scan_dir, args.port)
    elif args.download:
        retrieve_allowlist(args.timestamp, args.port)


if __name__ == "__main__":
    main_parser = argparse.ArgumentParser(add_help=False)
    main_parser.add_argument("--upload", action="store_true")
    main_parser.add_argument("--download", action="store_true")
    main_parser.add_argument("--port", required=True, type=int, help="Port number")
    main_args, _ = main_parser.parse_known_args()

    parser = argparse.ArgumentParser(parents=[main_parser])
    if main_args.upload:
        parser.add_argument(
            "--output-scan-dir",
            type=str,
            required=main_args.upload,
            help="Directory where all results are.",
        )
    elif main_args.download:
        parser.add_argument(
            "--timestamp",
            type=str,
            required=main_args.download,
            help="Timestamp in the format YYYYMMDD",
        )

    args, _ = parser.parse_known_args()
    if main_args.download or main_args.upload:
        main(args)
    else:
        parser.print_help()
