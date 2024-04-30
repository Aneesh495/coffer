// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;

@test:Config {}
function testFixedPointConstruction() returns error? {
    ScaledDecimal valA = check fromString("1250.75");
    test:assertEquals(valA.value, 1250.75d);
    test:assertEquals(valA.scale, 4);

    ScaledDecimal fromCents = fromMinorUnits(125075, 2);
    test:assertEquals(fromCents.value, 1250.75d);

    int backToCents = toMinorUnits(fromCents, 2);
    test:assertEquals(backToCents, 125075);
}

@test:Config {}
function testFixedPointArithmeticOperations() returns error? {
    ScaledDecimal a = check fromString("100.50");
    ScaledDecimal b = check fromString("25.25");

    ScaledDecimal sumResult = add(a, b);
    test:assertEquals(sumResult.value, 125.75d);

    ScaledDecimal diffResult = sub(a, b);
    test:assertEquals(diffResult.value, 75.25d);

    ScaledDecimal prodResult = mul(a, b);
    test:assertEquals(prodResult.value, 2537.625d);

    ScaledDecimal quotResult = check div(a, b);
    test:assertEquals(compare(quotResult, check fromString("3.98")), 1);
}

@test:Config {}
function testFixedPointDivisionByZero() {
    var zeroDiv = fromString("0.0");
    if zeroDiv is ScaledDecimal {
        var num = fromString("100.0");
        if num is ScaledDecimal {
            var err = div(num, zeroDiv);
            test:assertTrue(err is error);
        }
    }
}

@test:Config {}
function testFixedPointFormattingAndBankers() returns error? {
    ScaledDecimal val = check fromString("9999.876");
    string formatted = formatFinancial(val, 2);
    test:assertEquals(formatted, "9999.88");

    ScaledDecimal valZero = check fromString("0.0");
    test:assertTrue(isZero(valZero));

    ScaledDecimal valNeg = check fromString("-45.50");
    test:assertTrue(isNegative(valNeg));
    test:assertEquals(abs(valNeg).value, 45.50d);
}

@test:Config {}
function testFixedPointSaturatingSub() returns error? {
    ScaledDecimal balance = check fromString("50.00");
    ScaledDecimal debitSmall = check fromString("30.00");
    ScaledDecimal debitExcess = check fromString("100.00");

    ScaledDecimal remA = saturatingSub(balance, debitSmall);
    test:assertEquals(remA.value, 20.00d);

    ScaledDecimal remB = saturatingSub(balance, debitExcess);
    test:assertEquals(remB.value, 0.0d);
}

@test:Config {}
function testFixedPointBalanceVerification() returns error? {
    ScaledDecimal d1 = check fromString("500.00");
    ScaledDecimal d2 = check fromString("250.50");
    ScaledDecimal c1 = check fromString("750.50");

    test:assertTrue(verifyBalance([d1, d2], [c1]));

    ScaledDecimal cUnbalanced = check fromString("750.00");
    test:assertFalse(verifyBalance([d1, d2], [cUnbalanced]));
}
