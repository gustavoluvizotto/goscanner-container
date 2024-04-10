#!/usr/bin/env python3
"""
Upload all files from shared_dir/output dir to objstore
"""

__author__ = "Gustavo Luvizotto Cesar"
__email__ = "g.luvizottocesar@utwente.nl"

import argparse
from glob import glob

from storage_path import GoScannerStoragePath
from objstore import ObjStore


def main(args):
    """
    asd
    """
    transfer_to_objstore(args.output_scan_dir, args.port)


def transfer_to_objstore(output_scan_dir: str, port: int) -> None:
    for result_file in glob(f"{output_scan_dir}/*"):
        _uploader(result_file, port)


def _uploader(result_file, port):
    """asd
    Args:
        result_file (str): E.g. shared_dir/output/hosts.csv
        port (int): E.g. 389
    """
    objstore = ObjStore("catrin")
    filename = result_file.split("/")[-1]
    target_file = GoScannerStoragePath().get_path(filename, port)
    _ = objstore.upload(result_file, target_file)
    print(f"Uploaded {result_file} to {target_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-scan-dir",
        required=True,
        type=str,
        help="Directory where all results are.",
    )
    parser.add_argument(
        "--port",
        required=True,
        type=int,
        help="Port number",
    )
    main(parser.parse_args())
