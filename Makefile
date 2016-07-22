# Copyright 2016 Open Permissions Platform Coalition
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software distributed under the License is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

.PHONY: clean requirements test pylint html docs

# You should no set these variables from the command line.
# Directory that this Makfile is in
SERVICEDIR        = $(shell pwd)

# Directory containing the source code
SOURCE_DIR        = bass

# Directory to output the test reports
TEST_REPORTS_DIR  = tests/unit/reports

# You can set these variables from the command line.
# App to build docs from python sphinx commented code
SPHINXAPIDOC      = sphinx-apidoc

# Directory to build docs in
BUILDDIR          = $(SERVICEDIR)/_build

# Service version (required for $(SPHINXAPIDOC))
SERVICE_VERSION   = 0.4.0

# Service release (required for $(SPHINXAPIDOC))
SERVICE_RELEASE   = 0.4.0

# Directory to output python in source sphinx documentation
IN_SOURCE_DOC_DIR = $(BUILDDIR)/in_source

# Directory to output rst converted docs to
SERVICE_DOC_DIR   = $(BUILDDIR)/service/html

# Directory to find rst docs
DOC_DIR           = $(SERVICEDIR)/documents

# Directory to find rst docs
SPHINX_DIR           = $(SERVICEDIR)/docs

# Create list of target .html file names to be created based on all .rst files found in the 'doc directory'
rst_docs :=  $(patsubst $(DOC_DIR)/%.rst,$(SERVICE_DOC_DIR)/%.html,$(wildcard $(DOC_DIR)/*.rst)) \
                $(SERVICE_DOC_DIR)/README.html

clean:
	rm -fr $(TEST_REPORTS_DIR)

# Install requirements
requirements:
	pip install -r $(SERVICEDIR)/requirements.txt

# Run tests
test:
	mkdir -p $(TEST_REPORTS_DIR)
	py.test \
		-s \
		--cov $(SOURCE_DIR) tests \
		--cov-report html \
		--cov-report xml \
		--junitxml=$(TEST_REPORTS_DIR)/unit-tests-report.xml
	cloverpy $(TEST_REPORTS_DIR)/coverage.xml > $(TEST_REPORTS_DIR)/clover.xml

# Run pylint
pylint:
	mkdir -p $(TEST_REPORTS_DIR)
	@pylint $(SOURCE_DIR)/ --output-format=html > $(TEST_REPORTS_DIR)/pylint-report.html || {\
	 	echo "\npylint found some problems."\
		echo "Please refer to the report: $(TEST_REPORTS_DIR)/pylint-report.html\n";\
	 }

# Create .html docs from source code comments in python sphinx format
sphinx:
	$(SPHINXAPIDOC) \
		-s rst \
		--full \
		-V $(SERVICE_VERSION) \
		-R $(SERVICE_RELEASE) \
		-H $(SOURCE_DIR) \
		-A "Open Permissions Platform Coalition" \
		-o $(SPHINX_DIR) $(SOURCE_DIR)
	patch $(SPHINX_DIR)/index.rst docs/index.rst.patch

html: sphinx
	cd $(SPHINX_DIR) && PYTHONPATH=$(SERVICEDIR) make html BUILDDIR=$(IN_SOURCE_DOC_DIR)



# Dependencies of .html document files created from files in the 'doc directory'
$(SERVICE_DOC_DIR)/%.html : $(DOC_DIR)/%.rst
	mkdir -p $(dir $@)
	rst2html.py $< $@

# Dependenciy of .html document files created from README.rst
$(SERVICE_DOC_DIR)/%.html : %.rst
	mkdir -p $(dir $@)
	rst2html.py $< $@

# Create .html docs from all rst files
rst_docs: $(rst_docs)
ifneq ($(wildcard $(DOC_DIR)),)
# Copy dependent files required to render the views, e.g. images
	rsync \
		--exclude '*.rst' \
		--exclude 'eap' \
		--exclude 'drawio' \
		-r \
		$(DOC_DIR)/ $(SERVICE_DOC_DIR)
endif

# Create all docs
docs: html rst_docs

behave:
	cd tests/behave && behave features -v --junit --junit-directory reports

# Create egg_locks
egg_locks:
	top_level="$(SERVICEDIR)/requirements_top_level.txt" ; \
	if [ -e $$top_level ]; then \
		venv_path="$(SERVICEDIR)/_requirements_" ; \
		req_file="$(SERVICEDIR)/requirements.txt" ; \
		rm -rf $$venv_path ; \
		virtualenv $$venv_path ; \
		source $$venv_path"/bin/activate" ; \
		pip install -r $$top_level ; \
		echo "################################################" > $$req_file ; \
		echo "## DO NOT EDIT - AUTOMATICALLY GENERATED FILE ##" >> $$req_file ; \
		echo "################################################" >> $$req_file ; \
		pip freeze >> $$req_file ; \
		deactivate ; \
		rm -rf $$venv_path ; \
		sed -i '' -e 's|behave==\(.*\)|git+https://github.com/CDECatapult/behave.git@v\1|g' $$req_file ; \
	fi;
