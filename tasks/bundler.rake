package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "DAILY"
version: 1
update_configs:
  - package_manager: "javascript"
  - directory: "/"
    update_schedule: "as needed"
    updates:
      - dependencies:  "rspec*" 
      updates:
  - package-ecosystem: "npm"
    directory: "/"
"update_schedule": "as needed"
    groups:
      angular:
        patterns:
        - "@angular"
        - "@type_script"
        - "@javascript"
        update-types:
        - "minor"
        - "patch"
        -  "major" 
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "daily"
updates:
  - package-ecosystem: "type_script"
    directory: "/"
    schedule:
      interval: "daily"
      version: 2
updates:
  - package-ecosystem: "php"
    directory: "/"
    schedule:
      interval: "daily"
      
  
      




name: CI
on:
  pull_request:
  push:
    branches:
      - main

jobs:
  lint:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest]
        node_version: [16]
      fail-fast: false

    name: "Lint: node-${{ matrix.node_version }}, ${{ matrix.os }}"
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Set node version to ${{ matrix.node_version }}
        uses: actions/setup-node@v2
        with:
          node-version: ${{ matrix.node_version }}
          cache: yarn
      - name: Install dependencies
        run: yarn install
      - name: Lint js
        run: yarn lint
      - name: Lint typescript definitions
        run: yarn lint:ts
      - name: Check prettier
        run: yarn prettier:check

  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest]
        node_version: [10, 12, 14, 16]
        include:
          - os: macos-latest
            node_version: 14
      fail-fast: false

    name: "Build&Test: node-${{ matrix.node_version }}, ${{ matrix.os }}"
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Set node version to ${{ matrix.node_version }}
        uses: actions/setup-node@v2
        with:
          node-version: ${{ matrix.node_version }}
          cache: yarn
      - name: Install dependencies
        run: yarn install
      - name: Run tests
        run: yarn test



+++++++++++++++++××+


version: 2.1
parameters:
  run_flaky_tests:
    type: boolean
    default: false
orbs:
  browser-tools: circleci/browser-tools@1.4.4
jobs:
  build:
    docker:
      - image: cimg/node:20.0.0-browsers

    resource_class:
      xlarge
    working_directory: ~/remix-project
    steps:
      - checkout
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "yarn.lock" }}
      - run: yarn
      - save_cache:
          key: v1-deps-{{ checksum "yarn.lock" }}
          paths:
            - node_modules
      - run:
          name: Build
          command: |
            if [ "${CIRCLE_BRANCH}" == "master" ]; then
              NX_BIN_URL=http://127.0.0.1:8080/assets/js/soljson NX_WASM_URL=http://127.0.0.1:8080/assets/js/soljson NPM_URL=http://localhost:9090/ yarn build:production
            else
              NX_BIN_URL=http://127.0.0.1:8080/assets/js/soljson NX_WASM_URL=http://127.0.0.1:8080/assets/js/soljson NPM_URL=http://localhost:9090/ yarn build
            fi
      - run: yarn run build:e2e
      
      - run: grep -ir "[0-9]+commit" apps/* libs/* --include \*.ts --include \*.tsx --include \*.json > soljson-versions.txt
      - restore_cache:
          keys:
            - soljson-v7-{{ checksum "soljson-versions.txt" }}
      - run: yarn run downloadsolc_assets_e2e
      - save_cache:
          key: soljson-v7-{{ checksum "soljson-versions.txt" }}
          paths:
            - dist/apps/remix-ide/assets/js/soljson
      
      - run: mkdir persist && zip -0 -r persist/dist.zip dist
      - persist_to_workspace:
          root: .
          paths:
            - "persist"


  build-plugin:
      docker:
      - image: cimg/node:20.0.0-browsers
      resource_class:
        xlarge
      working_directory: ~/remix-project
      parameters:
        plugin:
          type: string
      steps:
        - checkout
        - restore_cache:
            keys:
              - v1-deps-{{ checksum "yarn.lock" }}
        - run: yarn
        - save_cache:
            key: v1-deps-{{ checksum "yarn.lock" }}
            paths:
              - node_modules
        - run: yarn nx build << parameters.plugin >> --configuration=production 
        - run: mkdir persist && zip -0 -r persist/plugin-<< parameters.plugin >>.zip dist
        - persist_to_workspace:
            root: .
            paths:
              - "persist"

  lint:
    docker:
      - image: cimg/node:20.0.0-browsers
    resource_class:
      xlarge
    working_directory: ~/remix-project

    steps:
      - checkout
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "yarn.lock" }}
      - run: yarn
      - run: yarn nx graph --file=./projects.json 
      - run:
          name: Remix Libs Linting
          command: node ./apps/remix-ide/ci/lint-targets.js
  remix-libs:
    docker:
      - image: cimg/node:20.0.0-browsers
    resource_class:
      xlarge
    working_directory: ~/remix-project

    steps:
      - checkout
      - attach_workspace:
          at: .
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "yarn.lock" }}
      - run: yarn --version
      - run: yarn
      - run: yarn build:libs
      - run: cd dist/libs/remix-tests && yarn
      - run: cd dist/libs/remix-tests && yarn add @remix-project/remix-url-resolver ../../libs/remix-url-resolver
      - run: cd dist/libs/remix-tests && yarn add @remix-project/remix-lib ../../libs/remix-lib
      - run: cd dist/libs/remix-tests && yarn add @remix-project/remix-solidity ../../libs/remix-solidity
      - run: cd dist/libs/remix-tests && yarn add @remix-project/remix-simulator ../../libs/remix-simulator
      - run: cd dist/libs/remix-tests && ./bin/remix-tests ./../../../libs/remix-tests/tests/examples_0/assert_ok_test.sol
      - run: node dist/libs/remix-tests/bin/remix-tests ./libs/remix-tests/tests/examples_0/assert_ok_test.sol
      - run: yarn run test:libs

  remix-ide-browser:
    docker:
      - image: cimg/node:20.0.0-browsers
    resource_class:
      xlarge
    working_directory: ~/remix-project
    parameters:
      browser:
        type: string
      script:
        type: string
      job:
        type: string
      jobsize:
        type: string
    parallelism: 10
    steps:
      - when:
          condition:
              equal: [ "chrome", << parameters.browser >> ]
          steps:
            - browser-tools/install-browser-tools:
                install-firefox: false
                install-chrome: true
                install-chromedriver: false
                install-geckodriver: false
            - install-chromedriver-custom-linux
            - run: google-chrome --version
            - run: chromedriver --version
            - run: rm LICENSE.chromedriver 2> /dev/null || true
      - when:
          condition:
              equal: [ "firefox", << parameters.browser >> ]
          steps:
            - browser-tools/install-browser-tools:
                install-firefox: true
                install-chrome: false
                install-geckodriver: true
                install-chromedriver: false
            - run: firefox --version
            - run: geckodriver --version
      - checkout
      - attach_workspace:
          at: .
      - run: unzip ./persist/dist.zip
      - run: yarn install --cwd ./apps/remix-ide-e2e --modules-folder ../../node_modules

      - run: ls -la ./dist/apps/remix-ide/assets/js
      - run: yarn run selenium-install || yarn run selenium-install
      - when:
          condition:
              equal: [ "chrome", << parameters.browser >> ]
          steps:
            - run: cp ~/bin/chromedriver /home/circleci/remix-project/node_modules/selenium-standalone/.selenium/chromedriver/latest-x64/
      - run:
          name: Start Selenium
          command: yarn run selenium
          background: true
      - run: ./apps/remix-ide/ci/<< parameters.script >> << parameters.browser >> << parameters.jobsize >> << parameters.job >>
      - store_test_results:
          path: ./reports/tests
      - store_artifacts:
          path: ./reports/screenshots

  tests-passed:
    machine:
      image: ubuntu-2004:202010-01
    steps:
      - run: echo done

  remix-test-plugins:
    docker:
      - image: cimg/node:20.0.0-browsers
    resource_class:
      xlarge
    working_directory: ~/remix-project
    parameters:
      plugin:
        type: string
      parallelism:
        type: integer
        default: 1
    parallelism: << parameters.parallelism >>
    steps:
      - browser-tools/install-browser-tools:
          install-firefox: false
          install-chrome: true
          install-geckodriver: false
          install-chromedriver: false
      - install-chromedriver-custom-linux
      - run: google-chrome --version
      - run: chromedriver --version
      - run: rm LICENSE.chromedriver 2> /dev/null || true
      - checkout
      - attach_workspace:
          at: .
      - run: unzip ./persist/dist.zip
      - run: unzip ./persist/plugin-<< parameters.plugin >>.zip
      - run: yarn install --cwd ./apps/remix-ide-e2e --modules-folder ../../node_modules
      - run: yarn run selenium-install || yarn run selenium-install
      - run: cp ~/bin/chromedriver /home/circleci/remix-project/node_modules/selenium-standalone/.selenium/chromedriver/latest-x64/
      - run:
          name: Start Selenium
          command: yarn run selenium
          background: true
      - run: ./apps/remix-ide/ci/browser_test_plugin.sh << parameters.plugin >>
      - store_test_results:
          path: ./reports/tests
      - store_artifacts:
          path: ./reports/screenshots


  predeploy:
    docker:
      - image: cimg/node:20.0.0-browsers
    resource_class:
      xlarge
    working_directory: ~/remix-project
    steps:
      - checkout
      - restore_cache:
          keys:
            - v1-deps-{{ checksum "yarn.lock" }}
      - run: yarn
      - save_cache:
          key: v1-deps-{{ checksum "yarn.lock" }}
          paths:
            - node_modules
      - run: yarn build:production
      - run: mkdir persist && zip -0 -r persist/predeploy.zip dist
      - persist_to_workspace:
          root: .
          paths:
            - "persist"

  deploy-build:
    docker:
      - image: cimg/node:20.0.0-browsers

    resource_class:
      xlarge
    environment:
      COMMIT_AUTHOR_EMAIL: "yann@ethereum.org"
      COMMIT_AUTHOR: "Circle CI"
    working_directory: ~/remix-project

    parameters:
      script:
        type: string

    steps:
      - checkout
      - attach_workspace:
          at: .
      - run: unzip ./persist/predeploy.zip
      - run: ./apps/remix-ide/ci/deploy_from_travis_remix-<< parameters.script >>.sh
    
workflows:
  run_flaky_tests:
    when: << pipeline.parameters.run_flaky_tests >>
    jobs:
      - build
      - remix-ide-browser:
          requires:
            - build
          matrix:
            parameters:
              browser: ["chrome", "firefox"]
              script: ["flaky.sh"]
              job: ["nogroup"]
              jobsize: ["1"]
  build_all:
    unless: << pipeline.parameters.run_flaky_tests >>
    jobs:
      - build
      - build-plugin:
          matrix:
            parameters:
              plugin: ["plugin_api"]
      - lint:
          requires:
            - build
      - remix-libs
      - remix-test-plugins:
          name: test-plugin-<< matrix.plugin >>
          requires:
            - build
            - build-plugin
          matrix:
            alias: plugins
            parameters:
              plugin: ["plugin_api"]
              parallelism: [1, 9]
            exclude: 
              - plugin: plugin_api
                parallelism: 1

      - remix-ide-browser:
          requires:
            - build
          matrix:
            parameters:
              browser: ["chrome", "firefox"]
              script: ["browser_test.sh"]
              job: ["0","1","2","3","4","5","6","7","8","9"]
              jobsize: ["10"]
      - tests-passed:
          requires:
            - lint
            - remix-libs
            - remix-ide-browser
            - plugins
            
      - predeploy:
          filters:
            branches:
              only: ['master', 'remix_live', 'remix_beta']
      - deploy-build:
          script: "live"
          name: "deploy-live"
          requires:
            - lint
            - remix-libs
            - remix-ide-browser
            - plugins
            - predeploy
          filters:
            branches:
              only: remix_live
      - deploy-build:
          script: "alpha"
          name: "deploy-alpha"
          requires:
            - lint
            - remix-libs
            - remix-ide-browser
            - plugins
            - predeploy
          filters:
            branches:
              only: master
      - deploy-build:
          script: "beta"
          name: "deploy-beta"
          requires:
            - lint
            - remix-libs
            - remix-ide-browser
            - plugins
            - predeploy
          filters:
            branches:
              only: remix_beta

# VS Code Extension Version: 1.5.1
commands:
  install-chromedriver-custom-linux:
    description: Custom script to install chromedriver with better version support for linux
    steps:
      - run:
          name: install-chromedriver-custom-linux
          command: |
            google-chrome --version > version.txt
            VERSION=$(grep -Eo '[0-9]+\.' < version.txt | head -1)
            # CHROMEDRIVER_URL=$(curl -s 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json' | jq '.channels.Stable.downloads.chromedriver[] | select(.platform == "linux64") | .url' | tr -d '"')
            CHROMEDRIVER_URL=$(curl -s 'https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json' | jq --arg v "$VERSION" '.versions[] | select(.version | startswith($v)) | .downloads.chromedriver[] | select(.platform == "linux64") | .url' | tail -n1 | tr -d '"')
            echo $CHROMEDRIVER_URL
            ZIPFILEPATH="/tmp/chromedriver.zip"
            echo "Downloading from $CHROMEDRIVER_URL"
            curl -f --silent $CHROMEDRIVER_URL > "$ZIPFILEPATH"

            BINFILEPATH="$HOME/bin/chromedriver-linux"
            echo "Extracting to $BINFILEPATH"
            unzip -p "$ZIPFILEPATH" chromedriver-linux64/chromedriver > "$BINFILEPATH"

            echo Setting execute flag
            chmod +x "$BINFILEPATH"

            echo Updating symlink
            ln -nfs "$BINFILEPATH" ~/bin/chromedriver

            echo Removing ZIP file
            rm "$ZIPFILEPATH"
            rm version.txt

            echo Done
            chromedriver -v

require "bundler
/setup"
Bundler:
:GemHelper.
install_tasks
