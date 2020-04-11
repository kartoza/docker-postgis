# TESTING GUIDE


## TL;DR; How to run the test

Go into root repo and run

```
./build-test.sh
```

It will create a tagged image `kartoza/postgis:manual-build`

Each scenario tests in this directory use this image.

To run each scenario test, go into the scenario directory and run test script:

```
# Testing collations scenario
cd collations
./test.sh
```

## Testing architecture

We make two stage of testing in travis.
First build stage, we build the image, push it into docker hub. 
Then the testing stage will 
use this image to run each scenario tests (run in parallel).

Any testing framework can be used, but we use python `unittest` module for simplicity and readability.

Due to the shared testing image used for other scenarios, for simplicity, put 
relevant python dependencies on `utils/requirement.txt`. 

For OS level dependencies, include your setup in the root folder's `Dockerfile.test`

## Making new tests

Create new directory in this folder (`scenario_tests`).
Directory should contains:

- Host level test script called `test.sh`
- `docker-compose.yml` file for the service setup
- `.env` file if needed for `docker-compose.yml` settings
- `tests` directory which contains your test scripts. The testing architecture will
  execute `test.sh` script in this directory (service level), if you use generic host level `test.sh` script.


Explanations:

Host level test script is used to setup the docker service, then run the unit test when 
the service is ready. You can copy paste from existing `collations` for generic script.

`docker-compose.yml` file should mount your `tests` directory and provides settings 
needed by the service that are going to be tested.

`tests` directory contains the actual test script that will be run from *inside* 
the service. For example, in `collations` scenario `test.sh` (service level scripts) 
will start python unittest script with necessary variables.

Add your scenario to travis config:

In `jobs.include[]` list there will be `stage: test` entry.
Add your environment variable needed to run your test in `stage.env` list.
For example, if you have new scenario folder `my_test`, then the env key 
will look like this:

```
- stage: test
  env:
    - SCENARIO=replications
    - SCENARIO=collations
    - SCENARIO=my_test EXTRA_SETTING_1=value1 EXTRA_SETTING_2=value2 EXTRA_SETTING_3=value3 
```
