#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <file.F> [preprocessor flags]"
    exit 1
fi

file="$1"
args="$2"

filename=$(echo "$file" | sed 's/\.[^.]*$//')
head -n 8 "$file" > .__poly_top.f
tail -n +9 "$file" > .__poly_bottom.F
benchdir=$(dirname "$file")

# 1. Run the preprocessor
# We use 'cpp' to avoid the f951 dependency issue found earlier
cpp -P -traditional-cpp .__poly_bottom.F -I "$benchdir" $args > .__tmp_poly.f

if [ $? -ne 0 ]; then
    echo "  [!] Error: Preprocessing failed for $file"
    rm -f .__tmp_poly.f .__poly_bottom.f .__poly_top.f .__poly_bottom.F
    exit 1
fi

# 2. Clean up and Modernize the code
# - Remove preprocessor markers and empty lines
# - Replace IARGC() with COMMAND_ARGUMENT_COUNT()
# - Replace '' with ' ' (a space) to fix the empty character constant error
# - Replace GETARG with GET_COMMAND_ARGUMENT for standard compliance
#-e "s/''/' '/g" \
sed -e '/^#/d' \
    -e '/^[ ]*$/d' \
    -e 's/IARGC()/COMMAND_ARGUMENT_COUNT()/gI' \
    -e 's/CALL GETARG/CALL GET_COMMAND_ARGUMENT/gI' \
    -e '/implicit none/d' \
    .__tmp_poly.f > .__poly_bottom.f

# 3. Assemble
cat .__poly_top.f > "${filename}.preproc.f90"
cat .__poly_bottom.f >> "${filename}.preproc.f90"

rm -f .__tmp_poly.f .__poly_bottom.f .__poly_top.f .__poly_bottom.F