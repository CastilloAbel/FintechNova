# This built-in Terraform resource makes no AWS or other cloud API calls.
resource "terraform_data" "gitlab_backend_probe" {
  input = {
    purpose = "Verify the GitLab HTTP state backend and lock support before AWS provisioning."
  }
}
