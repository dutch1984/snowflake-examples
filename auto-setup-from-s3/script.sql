-- Aanmaken van de database en het benodigde schema
CREATE DATABASE IF NOT EXISTS administratie;
CREATE SCHEMA IF NOT EXISTS administratie.init_setup;

-- Selecteren van het schema
USE SCHEMA administratie.init_setup;

-- Aanmaken van de storage integration voor de S3 bucket waar de
-- bestanden nodig voor initialisatie komen te staan.
CREATE OR REPLACE STORAGE INTEGRATION init_setup_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<iam_role>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/<path>/', 's3://<bucket>/<path>/');

-- Ophalen van de beschrijving van de integratie voor het updaten van de AWS role.
DESC INTEGRATION init_setup;

-- Het aanmaken van een file format doen we zelf. Zo houden we volledige controle over
-- wat wordt verwacht.
CREATE OR REPLACE FILE FORMAT init_setup_file_format
  TYPE = CSV
  COMPRESSION = NONE;

-- Het aanmaken van een external stage op basis van de integratie.
CREATE OR REPLACE STAGE init_setup_stage
  URL = 's3://location_of_files/'
  STORAGE_INTEGRATION = init_setup_integration
  FILE_FORMAT = init_setup_file_format;

-- Het aanmaken van een externe tabel op de external stage.
CREATE OR REPLACE EXTERNAL TABLE init_setup_table (
  statement VARCHAR
)
LOCATION = @init_setup_stage
AUTO_REFRESH = true
FILE_FORMAT = init_setup_file_format;

-- Aanmaken van de benodigde stream
CREATE OR REPLACE STREAM init_setup_stream ON EXTERNAL TABLE init_setup_table INSERT_ONLY = true;