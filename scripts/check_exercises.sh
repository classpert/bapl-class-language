#!/usr/bin/env bash

EXIT_CODE=0
for sut in $(find . -iregex ".*\(exercise_.*\|lesson_test\).lua"); do
    echo "Running tests in ${sut}" 
    sut_dir=$(dirname ${sut}) 
    sut_file=$(basename ${sut})
    sut_index=$(echo $sut_file | grep -o "[0-9]\+")
    LUA_PATH="${sut_dir}/?.lua;${sut_dir}/components_${sut_index}/?.lua;;" lua ${sut}
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
done

exit $EXIT_CODE
