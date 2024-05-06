// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;
import aneeshkrishna/coffer.fixedpoint;

# Regression test for Bug #1: Fixed-point decimal formatting truncation error.
# Prior to fix, casting a fractional decimal quotient to int rounded instead of truncating
# towards zero, causing whole integer components like 9999.88 to format as 10000.88.
#
# + return - Optional error on assertion failure
@test:Config {}
function testRegressionBugFixedpointTruncation() returns error? {
    fixedpoint:ScaledDecimal dec = check fixedpoint:fromString("9999.876");
    string formatted = fixedpoint:formatFinancial(dec, 2);
    test:assertEquals(formatted, "9999.88");

    fixedpoint:ScaledDecimal decSmall = check fixedpoint:fromString("0.999");
    string formattedSmall = fixedpoint:formatFinancial(decSmall, 2);
    test:assertEquals(formattedSmall, "1.00");

    fixedpoint:ScaledDecimal decEdge = check fixedpoint:fromString("199.994");
    string formattedEdge = fixedpoint:formatFinancial(decEdge, 2);
    test:assertEquals(formattedEdge, "199.99");
}
