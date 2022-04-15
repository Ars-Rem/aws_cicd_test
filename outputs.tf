// // // output "key_id" {
// // //   value = aws_kms_key.my_kms_key.key_id
// // // }

// // // output "key_arn" {
// // //   value = aws_kms_key.my_kms_key.arn
// // // }


// output "role_arn" {
//   value = aws_iam_role.codepipeline_role.arn
// }
// output "ConnectionArn" {
//   value = aws_codestarconnections_connection.example.arn
// }
// output "aws_codepipeline_role_arn" {
//   value = aws_iam_role.codepipeline_role.arn
// }
// output "location" {
//   value = aws_s3_bucket.codepipeline_bucket.bucket
// }


// output "codestar" {
//     value = aws_codestarconnections_connection.example.arn
// }
// output "git" {
//   value = aws_secretsmanager_secret.to_git.arn
// }

// output "FullRepositoryId" {
//   value = aws_codecommit_repository.repository.clone_url_http
// }

output "service_role" {
  value = aws_iam_role.to-project.arn
}