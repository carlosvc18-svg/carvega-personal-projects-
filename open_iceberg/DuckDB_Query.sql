-- DuckDB (v0.10+)
INSTALL iceberg;
LOAD iceberg;
INSTALL httpfs;
LOAD httpfs;

SET s3_region = 'us-east-1';
SET s3_access_key_id = '<AWS_ACCESS_KEY>';
SET s3_secret_access_key = '<AWS_SECRET_KEY>';

-- Query directly from Iceberg metadata
SELECT *
FROM iceberg_scan(
    's3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/agg_adoption_by_county.3uj6PNnO/metadata/00001-8c09a182-6820-49a0-b84c-87fc9037ff47.metadata.json'
)
ORDER BY county_rank
LIMIT 10;

-- BEV vs PHEV share
SELECT county, ev_type, registration_count, pct_of_county
FROM iceberg_scan(
    's3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/agg_ev_type_share_by_county.TmF7rR79/metadata/00001-ee4b6a42-3d68-4412-adbe-484ca9271b9c.metadata.json'
)
WHERE county = 'King'
ORDER BY pct_of_county DESC;