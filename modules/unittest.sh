## Unit Test Framework

_BANG_TESTFUNCS=()
_BANG_ASSERTIONS_FAILED=0

## Adds test cases to be executed
## @param testcase - Function with assertions
function b.unittest.add_test_case () {
  is_function? "$1" && _BANG_TESTFUNCS+=($1)
}

## Asserts a function exit code is zero
## @param return code - return code of the command
function b.unittest.assert_success () {
  if [ $1 -gt 0 ]; then
    print_e "Expected a success, but exit code was '$1'"
    let _BANG_ASSERTIONS_FAILED++
    return 1
  fi
  return 0
}

## Asserts a functoin exit code is 1
## @param func_name - Name of the function
function b.unittest.assert_error () {
  if [ $1 -eq 0 ]; then
    print_e "Expected an error, but exit code was '0'"
    let _BANG_ASSERTIONS_FAILED++
    return 1
  fi
  return 0
}

## Asserts a function output is the same as required
## @param reqvalue - Value to be equals to the output
## @param func_name - Name of the function which result is to be tested
function b.unittest.assert_equal () {
  local val="$1"
  shift
  local result="$1"
  if [ "$val" != "$result" ]; then
    print_e "Expected '$val', but got '$result' instead"
    let _BANG_ASSERTIONS_FAILED++
    return 1
  fi
  return 0
}

## Asserts a function will raise a given exception
## @param func_name - a string containing the name of the function which will raise an exception
## @param exception - a string containing the exception which should be raise
function b.unittest.assert_raise () {
  local fired=0
  function catch_exception () { fired=1 ; }
  b.try.do "$1"
  b.catch "$2" catch_exception
  b.try.end
  if [ $fired -ne 1 ]; then
    print_e "Expected '$2', but '$1' has not raised any exception."
    let _BANG_ASSERTIONS_FAILED++
  fi
  unset -f catch_exception
}

## Do a double for a function, replacing it codes for the other functions' code
## @param func1 - a string containing the name of the function to be replaced
## @param func2 - a string containing the name of the function which will replace func1
function b.unittest.double.do () {
  if is_function? "$1" && is_function? "$2"; then
    local actualFunc=$(declare -f "$1" | sed '1d;2d;$d') \
          func=$(declare -f "$2" | sed '1d;2d;$d') \
          func_name="$1"
    b.set "bang.unittest.doubles.$func_name" "$actualFunc"
    local mocks="$(b.get bang.unittest.doubles)"
    b.set "bang.unittest.doubles" "$mocks $func_name"
    eval "function $1 () {
      $func
    }"
  fi
}

## Undo the double for the function
## @param func - the string containing the name of the function
function b.unittest.double.undo () {
  local key="bang.unittest.doubles.$1"
  if b.is_set? "$key"; then
    local func_body="$(b.get $key)"
    eval "function $1 () {
      $func_body
    }"
    b.unset "$key"
    local mocks="$(b.get bang.unittest.doubles)"
    b.set "bang.unittest.doubles" "${mocks//$1/}"
  fi
}

## Turns all doubled functions to its normal behavior
function b.unittest.double.undo_all () {
  IFS=" "
  for func_name in $(b.get 'bang.unittest.doubles'); do
    b.unittest.double.undo "$func_name"
  done
  unset IFS
}

## Returns a list of loaded test cases
function b.unittest.find_test_cases () {
  declare -f | grep '^b\.test\.' | sed 's/ ().*$//'
}

## Execute and return whether a test case was run successfuly
##
## @param test_case - a test case function name
function b.unittest.run_successfuly? () {
  (
    local test_case="$1"

    is_function? b.unittest.setup && b.unittest.setup
    $test_case
    is_function? b.unittest.teardown && b.unittest.teardown

    b.unittest.double.undo_all
    [ $_BANG_ASSERTIONS_FAILED -eq 0 ]
  )
}
