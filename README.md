### Setting up

Create an `.env` file inside the plugin folder where you'll be running tests:

```
GV_PLUGIN_DIR=/path/to/tooling/storage_folder/gv
GF_PLUGIN_DIR=/path/to/tooling/storage_folder/gf
WP_51_TESTS_DIR=/path/to/tooling/storage_folder/wp_tests_51
WP_LATEST_TESTS_DIR=/path/to/tooling/storage_folder/wp_tests_latest
PHPUNIT_DIR=/path/to/tooling/storage_folder/phpunit
GH_AUTH_TOKEN=<your GH token>
PLUGIN_DIR=${PWD}
```

Then execute `./docker-unit-tests.sh prepare_all` to set up the test environment and `./docker-unit-tests.sh test_74` to run tests. 