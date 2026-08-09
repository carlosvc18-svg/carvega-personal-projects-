from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.jars.packages",
            "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0,"
            "org.apache.iceberg:iceberg-aws-bundle:1.5.0") \
    .config("spark.sql.catalog.ev_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.ev_catalog.type", "hadoop") \
    .config("spark.sql.catalog.ev_catalog.warehouse",
            "s3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/") \
    .config("spark.hadoop.fs.s3a.access.key", "<AWS_ACCESS_KEY>") \
    .config("spark.hadoop.fs.s3a.secret.key", "<AWS_SECRET_KEY>") \
    .config("spark.hadoop.fs.s3a.endpoint", "s3.amazonaws.com") \
    .getOrCreate()

# Load directly from metadata location (no Snowflake involved)
adoption_df = spark.read.format("iceberg").load(
    "s3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/"
    "agg_adoption_by_county.3uj6PNnO/metadata/"
    "00001-8c09a182-6820-49a0-b84c-87fc9037ff47.metadata.json"
)

# Or register as a table and query with SQL
spark.sql("""
    CREATE TABLE ev_catalog.gold.adoption_by_county
    USING iceberg
    LOCATION 's3://amzn-s3-cv-demo-dol-iceberg-bucket/gold/agg_adoption_by_county.3uj6PNnO/'
""")

spark.sql("""
    SELECT county, registration_count, county_rank
    FROM ev_catalog.gold.adoption_by_county
    ORDER BY county_rank
    LIMIT 10
""").show()