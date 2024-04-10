#!/usr/bin/env python3
"""
Objstore handler
"""
__author__ = "Gustavo Luvizotto Cesar"
__email__ = "g.luvizottocesar@utwente.nl"

import base64
import hashlib

import boto3
from botocore.utils import fix_s3_host
import botocore

from config import BUF_SIZE, PORT
import credentials as c


class ObjStore(object):
    def __init__(self, bucket_name):
        self.bucket_name = bucket_name
        self.bucket = self.get_bucket()

    def get_bucket(self):
        s3 = self.get_s3()
        return s3.Bucket(self.bucket_name)

    def get_s3(self):
        # Change timeouts in case we are uploading large files.
        config = botocore.config.Config(
            connect_timeout=3, read_timeout=9999, retries={"max_attempts": 3}
        )

        s3 = boto3.resource(  # can also replace resource with client if you need that
            "s3",
            "nl-utwente-tee",
            aws_access_key_id=c.MINIO_ACCESS_USER,
            aws_secret_access_key=c.MINIO_ACCESS_PASSWORD,
            endpoint_url=f"http://localhost:{PORT}",
            config=config,
        )
        # next line is needed to prevent some request going to AWS instead of our server
        s3.meta.client.meta.events.unregister("before-sign.s3", fix_s3_host)
        return s3

    def upload(self, source_file, target_file):
        src_sha256digest = self._calculate_checksum(source_file)
        etag = base64.b64encode(src_sha256digest).decode(encoding="utf-8")
        with open(source_file, mode="rb") as f:
            # Upload the object to S3 with the specified ETag
            # https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/put_object.html#
            self.bucket.put_object(
                Bucket=self.bucket_name,
                Key=target_file,
                Body=f.read(),
                ChecksumSHA256=etag,
            )

        etag = [obj.e_tag for obj in self.bucket.objects.filter(Prefix=target_file)][
            -1
        ].strip('"')
        return etag

    def download(self, remote_file, destination):
        self.get_s3().meta.client.download_file(
            self.bucket_name, remote_file, destination, {"ChecksumMode": "ENABLED"}
        )

    @staticmethod
    def _calculate_checksum(local_filepath):
        sha256 = hashlib.sha256()
        with open(local_filepath, mode="rb") as f:
            while True:
                data = f.read(BUF_SIZE)
                if not data:
                    break
                sha256.update(data)
            sha256digest_bin = sha256.digest()
        return sha256digest_bin

    def is_file_already_uploaded(self, filepath: str) -> bool:
        objlist = list(self.bucket.objects.filter(Prefix=filepath))
        if len(objlist) > 0:
            return True
        else:
            return False
