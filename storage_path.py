#!/usr/bin/env python3
"""
Responsible to
"""
__author__ = "Gustavo Luvizotto Cesar"
__email__ = "g.luvizottocesar@utwente.nl"

from datetime import datetime, timezone

filename_scan_dict = {
    "hosts.csv": "tcp",
    # SSH scan results
    "host_keys.csv": "ssh",
    "relations.csv": "ssh",
    # TLS scan results
    "certs.csv": "tls",
    "cert_chain.csv": "tls",
    "scsv.csv": "scsv",
    "http.csv": "http",
    "http_verbose.csv": "http",
    "tls_verbose.csv": "tls",
    "dissectls.csv": "dissectls",
    "stapled_ocsp_responses.csv": "tls",
    "jarm.csv": "jarm",
    "tls-keylog": "tls",
    "fingerprints.csv": "tls",
    # other scan results
    "starttls_ldap.csv": "starttls_ldap",
    "ldap.csv": "ldap",
}


def _get_year_month_day(timestamp: str = None) -> str:
    if timestamp:
        dt = datetime.strptime(timestamp, "%Y%m%d")
    else:
        dt = datetime.now(timezone.utc)
    year = dt.year
    month = dt.month
    day = dt.day
    return f"year={year:02d}/month={month:02d}/day={day:02d}"


class GoScannerStoragePath(object):
    """asd"""

    def get_path(self, filename: str, port: int) -> str:
        """
        :param filename: E.g.
            cert_chain.csv  certs.csv  fingerprints.csv  hosts.csv  tls-keylog  tls_verbose.csv
        :param port: port number
        :return: E.g.
            measurements/tool=goscanner/format=raw/port=389/scan=tls/result=fingerprints/year=2023/month=07/day=27/fingerprints.csv

            List of possible results:
            https://github.com/tumi8/goscanner/blob/c24ae90b07a925629bfcb3d8c45085bb8ac34df1/scanner/results/result.go#L9
            List of possible scans:
            https://github.com/tumi8/goscanner/blob/c24ae90b07a925629bfcb3d8c45085bb8ac34df1/scanner/scanner.go#L20
        """
        year_month_day = _get_year_month_day()
        result = filename.split(".")[0]
        scan = filename_scan_dict[filename]
        return f"measurements/tool=goscanner/format=raw/port={port}/scan={scan}/result={result}/{year_month_day}/{filename}"


class AllowlistStoragePath(object):
    """asd"""

    @staticmethod
    def get_prefix(port: int) -> str:
        return f"measurements/tool=zmap/dataset=default/port={port}/"
