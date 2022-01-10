# Trade Tariff Backend

The Trade Tariff Backend provides an API which allows to search commodity codes for import and export for tax, duty and licences that apply to goods, from and to UK and NI.

It is maintained on https://github.com/trade-tariff/trade-tariff-backend

Projects using the Trade Tariff (TT) API:

* [Trade Tariff Frontend](https://github.com/trade-tariff/trade-tariff-frontend)
* [Trade Tariff Admin](https://github.com/trade-tariff/trade-tariff-admin)
* [Trade Tariff Duty Calculator](https://github.com/trade-tariff/trade-tariff-duty-calculator)

## Development

### Dependencies

  - Ruby [v3](https://github.com/trade-tariff/trade-tariff-frontend/blob/main/.ruby-version#L1)
  - Postgresql v10
  - ElasticSearch v7
  - Redis v4

### Setup

Please go through this updated [setup document](https://github.com/trade-tariff/trade-tariff-backend/blob/main/SETUP.md)

1. Setup your environment, by doing the following:

    - Run rails db:create - to create the databases locally

    - Setup your cf CLI: https://docs.cloudfoundry.org/cf-cli/install-go-cli.html

    - Check with DevOps to have a cf account created, if you don't have one already

    - Install [conduit plugin](https://plugins.cloudfoundry.org/#conduit). It allows you to directly connect to the remote service instances in Cloud Foundry.

    - Get a data dump of the DB from our DEV/STAGING environment, by running:

       ```
       cf conduit <target database> -- pg_dump --file <data_dump_file_name>.psql --no-acl --no-owner --clean --verbose
       ```

       For example:

       ```
       cf conduit trade-tariff-db -- pg_dump --file trade-tariff-db.psql
       ```

    - Restore the data dump locally, by running:

       ```
       psql -h localhost tariff_development < <data_dump_file_name>.psql
       ```

2. Update `.env` file with valid data. To enable the XI version, add the extra flag `SERVICE=xi`. If not added, it will default to the UK version.

3. Start your services:

    #### Manually

    - PostgreSQL Server

    Use the command
    `postgres -D /usr/local/pgsql/data`

    or

    `pg_ctl start`

    see https://www.postgresql.org/docs/10/server-start.html

    - Redis Server:

    `redis-server`

    - ElasticSearch

    cd to your ElasticSearch folder and run `./bin/elasticseach`

    - Sidekiq

    `bundle exec sidekiq`

    - Rails Server

    `bundle exec rails s`

    #### Using Docker compose

    TT backend contains a docker-compose.yml file to run Redis, ElasticSearch and Postgres:

    To start the services run:

    ```
    docker-compose up
    ```

    To stop them run:

    `docker-compose down`

    Notes:
    - docker-compose help you to start the depentencies, but you still need to run the trade tarif rails service:
    - Keep in mind the [difference between "up" and "start"](https://docs.docker.com/compose/faq/#whats-the-difference-between-up-run-and-start).


    ```
    bundle exec rails s
    ```

    This way facilitates development and debugging, allowing easy setup of the other services.


4. Verify that the app is up and running.

    E.g open http://localhost:3018/healthcheck


## Load database

Check out [wiki article on the subject](https://github.com/trade-tariff/trade-tariff-backend/wiki/System-rebuild-procedure), or get a [recent database snapshot](mailto:trade-tariff-support@enginegroup.com).


## Performing daily updates

These are run hourly by a background worker UpdatesSynchronizerWorker.


### Sync process

- checking failures (check tariff_synchronizer.rb) - if any of updates failed in the past, sync process will not proceed
- downloading missing files up to Date.today (check base_update.rb and download methods in taric_update.rb)
- applying downloaded files

Updates are performed in portions and protected by redis lock (see TariffSynchronizer#apply).

BaseUpdate#apply is responsible for most of the logging/checking job and running
`import!` methods located in Taric class. Then it runs TaricImporter
to parse and store xml files.

In case of any errors, changes (per single update) are roll-backed and record itself is marked as failed. The sync would need to be rerun after a rollback.


## Manual Deployment (This is automated via CircleCI now)

You can manually deploy to cloud foundry as well, so you need to have the CLI installed, and the following [cf plugin](https://github.com/bluemixgaragelondon/cf-blue-green-deploy) installed:

Set the following ENV variables:
* CF_USER
* CF_PASSWORD
* CF_ORG
* CF_SPACE
* CF_APP
* CF_APP_WORKER
* SLACK_CHANNEL
* SLACK_WEBHOOK

Then run

    ./bin/deploy

NB: In the newer Diego architecture from CloudFoundry, no-route skips creating and binding a route for the app, but does not specify which type of health check to perform. If your app does not listen on a port, for example the sidekiq worker, then it does not satisfy the port-based health check and Cloud Foundry marks it as crashed. To prevent this, disable the port-based health check with cf set-health-check APP_NAME none.


## Scaling the application

We are using CF [AutoScaler](https://github.com/cloudfoundry/app-autoscaler) plugin to perform application autoscaling. Set up guide and documentation are available by links below:

https://docs.cloud.service.gov.uk/managing_apps.html#autoscaling

https://github.com/cloudfoundry/app-autoscaler/blob/develop/docs/Readme.md


To check autoscaling history run:

    cf autoscaling-history APPNAME

To check autoscaling metrics run:

    cf autoscaling-metrics APP_NAME METRIC_NAME

To remove autoscaling policy and disable App Autoscaler run:

    cf detach-autoscaling-policy APP_NAME

To create or update autoscaling policy for your application run:

    cf attach-autoscaling-policy APP_NAME ./policy.json


Current autosscaling policy files are [here](https://github.com/trade-tariff/trade-tariff-backend/blob/main/config/autoscale).


## Notes

* When writing validators in `app/validators` please run the rake task
`audit:verify` which runs the validator against existing data.


## Contributing

Please check out the [Contributing guide](https://github.com/trade-tariff/trade-tariff-backend/blob/main/CONTRIBUTING.md)


## Licence

Trade Tariff is licenced under the [MIT licence](https://github.com/trade-tariff/trade-tariff-backend/blob/main/LICENCE.txt)
