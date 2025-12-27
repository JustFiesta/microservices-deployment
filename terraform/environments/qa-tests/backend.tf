terraform {
  backend "s3" {
    bucket         = "mbocak-kubernetes-tf-state-bucket"
    key            = "state/qa-tests/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}
