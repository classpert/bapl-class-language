#!/usr/bin/env bash

EXIT_CODE=0
for exercise in $(find . -iname "exercise_*.lua"); do
    lua ${exercise}
    if [ $? -ne 0 ]; then
        EXIT_CODE=1
    fi
done

exit $EXIT_CODE
