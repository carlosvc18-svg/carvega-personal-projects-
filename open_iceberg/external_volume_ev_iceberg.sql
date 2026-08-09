CREATE OR REPLACE EXTERNAL VOLUME EV_ICEBERG_VOL
  STORAGE_LOCATIONS = ((
    NAME = 'ev-s3-primary'
    STORAGE_PROVIDER = 'S3'
    STORAGE_BASE_URL = 's3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/'
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::412611736618:role/snowflake_admin_s3'
  ))
  ALLOW_WRITES = TRUE