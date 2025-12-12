terraform {
  backend "s3" {
    bucket         = "mbocak-kubernetes-tf-state-bucket"
    key            = "state/shared/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}
# reapply 1
