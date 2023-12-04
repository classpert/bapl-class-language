#!/usr/bin/env bash

EXIT_CODE=0
for sut in $(find . -iregex ".*\(exercise_.*\|lesson_test\).lua"); do
    echo "Running tests in ${sut}" 
    sut_dir=$(dirname ${sut}) 
    sut_file=$(basename ${sut})
    pushd ${sut_dir} > /dev/null
    lua ${sut_file}
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
    popd > /dev/null
done

exit $EXIT_CODE
