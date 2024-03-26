// creates a place to store our function
create database generate_data;
create schema generate_data.helper_functions;

// create a role that gives access to our function as wel as any other future functions we might add
create role helper_function_consumer;
grant usage on database generate_data to role helper_function_consumer;
grant usage on schema generate_data.helper_functions to role helper_function_consumer;
grant usage on future functions in schema generate_data.helper_functions to role helper_function_consumer;

// Make sure we are using the schema we just created
use schema generate_data.helper_functions;

// creates the function
create or replace function FAKE(locale varchar,provider varchar,parameters variant)
    returns variant
    language python
    volatile
    runtime_version = '3.8'
    packages = ('faker','simplejson')
    handler = 'fake'
as
$$
import simplejson as json
from faker import Faker
def fake(locale,provider,parameters):
  if type(parameters).__name__=='sqlNullWrapper':
    parameters = {}
  fake = Faker(locale=locale)
  return json.loads(json.dumps(fake.format(formatter=provider,**parameters), default=str))
$$;

// Granting the role to a user and trying to consuming the function will show a warehouse is required
grant role helper_function_consumer to user "RUUD"; // Use your won user here
use role helper_function_consumer;

select FAKE('en_US','name',null)::varchar as FAKE_NAME
 from table(generator(rowcount => 50));

// Create a warehouse and give to user permissions to consume it.
user role accountadmin;
create warehouse wh_helper_function_consumer
    warehouse_type = STANDARD
  warehouse_size = XSMALL
  auto_suspend = 300
  auto_resume = TRUE
  initially_suspended = TRUE;
grant usage on warehouse wh_helper_function_consumer to role helper_function_consumer;

// Show that using the warehouse we can consume the function
use role helper_function_consumer;
use warehouse wh_helper_function_consumer;

select FAKE('en_US','name',null)::varchar as FAKE_NAME
 from table(generator(rowcount => 50));

// Use the function to create a more advanced table created by the user in his own database
// Create the database and transfer ownership
use role accountadmin;
create database personal_consumers_database;
grant ownership on database personal_consumers_database to role helper_function_consumer;

// Create the table and schema to hold the table
use role helper_function_consumer;
create schema personal_consumers_database.mock_tables;
create or replace table personal_consumers_database.mock_tables.users (
  name varchar (100),
  year_of_birth integer,
  zip_code varchar(7),
  city varchar(30),
  phone_number varchar(16),
  favorite_float float
);

// Populate the table with mocked data using the Dutch locale
insert into personal_consumers_database.mock_tables.users
    select
        generate_data.helper_functions.FAKE('nl_NL','name',null)::varchar,
        generate_data.helper_functions.FAKE('nl_NL','random_int',{'min':1950,'max':2014})::integer,
        generate_data.helper_functions.FAKE('nl_NL','postcode',null)::varchar,
        generate_data.helper_functions.FAKE('nl_NL','city',null)::varchar,
        generate_data.helper_functions.FAKE('nl_NL','phone_number',null)::varchar,
        generate_data.helper_functions.FAKE('nl_NL','pyfloat',{'left_digits':2, 'right_digits':2, 'positive': True})::varchar
    from
        table(generator(rowcount => 50000));

// Show our mocked table
select * from personal_consumers_database.mock_tables.users;

