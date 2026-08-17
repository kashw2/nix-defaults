{
  flake.lib.mkS3Env =
    lib: services: buckets:
    lib.optionalAttrs (services.seaweedfs."storage:seaweedfs".enable or false) (
      lib.genAttrs buckets (
        bucket:
        (endpoint: {
          S3_ENDPOINT = endpoint;
          S3_REGION = "us-east-1";
          S3_BUCKET = bucket;
          S3_PUBLIC_URL = "${endpoint}/${bucket}";
          AWS_ACCESS_KEY_ID = "seaweedfsadmin";
          AWS_SECRET_ACCESS_KEY = "seaweedfsadmin";
        })
          "http://${services.seaweedfs."storage:seaweedfs".host}:${
            toString services.seaweedfs."storage:seaweedfs".s3.port
          }"
      )
    );
}
