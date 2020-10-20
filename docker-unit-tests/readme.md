### Setting up the test environment

1. Create an `.env` file inside the plugin folder where you'll be running tests:

   ```
   GV_PLUGIN_DIR=/path/to/storage_folder/gravityview
   GF_PLUGIN_DIR=/path/to/storage_folder/gravity_forms
   WP_51_TESTS_DIR=/path/to/storage_folder/wp_tests_51
   WP_LATEST_TESTS_DIR=/path/to/storage_folder/wp_tests_latest
   PHPUNIT_DIR=/path/to/storage_folder/phpunit
   GH_AUTH_TOKEN=<your GH token>
   PLUGIN_DIR=${PWD}
   ```
   
   (`/path/to/storage_folder/` is where a copy of dependencies will be saved). 

2. Execute `/path/to/docker-unit-tests.sh prepare_all` to set up the test environment. 

   Alternatively, you can pass these environment variables directly to the Bash script by executing `GV_PLUGIN_DIR=... GF_PLUGIN_DIR=xxx ./path/to/docker-unit-tests.sh prepare_all`

`GV_PLUGIN_DIR` is an optional environmental variable as it is only used with extensions that rely on GravityView's unit tests. For that reason, the `prepare_all` command does not download GravityView and you need to run the `download_gravityview` command separately or link to folder with the cloned GravityView repo.
### Running tests

To run tests, execute `/path/to/docker-unit-tests.sh test_74` (replace `74` with the desired PHP version: `54`, `55`, `56`, `70`, `71`, `72` or `73`).

You can test using all PHP versions by executing `/path/to/docker-unit-tests.sh test_all` or mixing and matching versions by using multiple commands (e.g., `test_54 test_56 test_72`).

To execute a single test, use the `-o` argument: `/path/to/docker-unit-tests.sh test_56 -o "TestClass::test_name"`. This argument will also work with the `test_all` command so that a single test can be executed using all available PHP versions.
