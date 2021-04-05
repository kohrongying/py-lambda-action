#!/bin/bash
set -euo pipefail

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "\nPublishing dependencies as a layer..."
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
        echo "Publish lambda layer successful!"
        echo "Lambda Layer Version: $LAYER_VERSION"
	rm -rf python
	rm dependencies.zip
}

files_to_exclude() {
        echo "exclude.lst" > exclude.lst
        echo ".git/*" >> exclude.lst
        read -ra ADDR <<< "$INPUT_EXCLUDE_FILES"
        for i in "${ADDR[@]}"; do
                echo "$i*" >> exclude.lst
        done
}

publish_function_code(){
	echo "\nDeploying the code itself..."
        files_to_exclude
	zip -r code.zip . -x@exclude.lst
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip > /dev/null
        if [ $? -eq 0 ]; then
                echo "Deploy lambda successful!"
        fi
        rm exclude.lst
}

update_function_layers(){
	echo "\nUsing the layer in the function..."
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}" > /dev/null
        if [ $? -eq 0 ]; then
                echo "Update lambda layer successful!"
        fi
}

deploy_lambda_function(){
        INPUT_LAMBDA_LAYER_PUBLISH=$(echo $INPUT_LAMBDA_LAYER_PUBLISH | tr "[:upper:]" "[:lower:]")
        if [ "$INPUT_LAMBDA_LAYER_PUBLISH" == "true" ]; then
                install_zip_dependencies
                publish_dependencies_as_layer
                publish_function_code
                update_function_layers
        else
                publish_function_code
        fi
}

deploy_lambda_function
echo "Done."
