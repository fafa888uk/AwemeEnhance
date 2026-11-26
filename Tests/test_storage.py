import unittest
from unittest.mock import patch
from tools.private_storage import StorageError, parse_s3, transfer, check_private


class StorageTests(unittest.TestCase):
    def test_valid_s3(self):
        self.assertEqual(parse_s3("s3://private-bucket/ipa/source.ipa"), ("private-bucket", "ipa/source.ipa"))

    def test_invalid_s3(self):
        for uri in ("https://example.com/a", "s3://bucket", "s3://USER:pass@bucket/key", "s3://bucket/key?secret=x", "s3://bucket/../key"):
            with self.subTest(uri=uri), self.assertRaises(StorageError):
                parse_s3(uri)

    @patch("tools.private_storage.aws")
    def test_no_cloud_calls_without_cost_authorization(self, mock):
        with self.assertRaisesRegex(StorageError, "charges"):
            transfer("get", "s3://private-bucket/key", "unused.ipa")
        mock.assert_not_called()

    @patch("tools.private_storage.aws", return_value=b'{"PublicAccessBlockConfiguration": {"BlockPublicAcls": true}}')
    def test_public_bucket_rejected(self, mock):
        with self.assertRaises(StorageError): check_private("private-bucket")

    @patch("tools.private_storage.aws", return_value=b'{"PublicAccessBlockConfiguration": {"BlockPublicAcls": true, "IgnorePublicAcls": true, "BlockPublicPolicy": true, "RestrictPublicBuckets": true}}')
    def test_private_bucket_accepted(self, mock):
        check_private("private-bucket")


if __name__ == "__main__":
    unittest.main()
