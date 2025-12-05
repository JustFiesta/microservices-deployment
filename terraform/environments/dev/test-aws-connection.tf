# reapply
resource "aws_s3_bucket" "test_bucket" {
  bucket = "mbocak-tf-connection-test-bucket"
  tags = {
    Name        = "TF Test Bucket"
    Environment = "dev"
  }
}
