#!/usr/bin/env python3
"""
Responsible to
"""
__author__ = "Gustavo Luvizotto Cesar"
__email__ = "g.luvizottocesar@utwente.nl"

import argparse
from datetime import datetime
import os

from storage_path import AllowlistStoragePath
from objstore import ObjStore

from config import ALLOWLIST_DIR


def main(args):
    retrieve_allowlist(args.timestamp, args.port)


def retrieve_allowlist(timestamp: str, port: int) -> None:
    prefix = AllowlistStoragePath.get_prefix(port)
    catrin = ObjStore("catrin")
    catrin_bucket = catrin.get_bucket()

    zmap_measurements = []
    for page in catrin_bucket.objects.pages():
        zmap_measurements += [meas.key for meas in page if prefix in meas.key]
    zmap_measurements.sort(reverse=True)

    allowlist = _get_latest_measurement(timestamp, zmap_measurements)
    filename = os.path.basename(allowlist)
    target = os.path.join(ALLOWLIST_DIR, filename)
    catrin.download(allowlist, target)


def _get_latest_measurement(timestamp, zmap_measurements):
    # zmap_measurements list has to be sorted!
    found_file = None
    for meas_path in zmap_measurements:
        filename = os.path.basename(meas_path)
        actual_date_str = os.path.splitext(filename)[0].split("_")[-1]
        dat_file_date = datetime.strptime(actual_date_str, "%Y%m%d%H%M%S")
        # discard hours, minutes and seconds to have a fair comparison
        dat_file_date = dat_file_date.replace(hour=0, minute=0, second=0)

        desired_date = datetime.strptime(timestamp, "%Y%m%d")
        if dat_file_date <= desired_date:
            found_file = meas_path
            break
    assert (
        found_file is not None
    ), "Could not find the closest file you were looking for"
    return found_file


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--timestamp", required=True, type=str, help="Timestamp in the format YYYYMMDD"
    )
    parser.add_argument("--port", required=True, type=int, help="Port number")
    main(parser.parse_args())
