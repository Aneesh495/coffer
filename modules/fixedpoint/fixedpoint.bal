// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import aneeshkrishna/coffer.types;

# Scaled decimal fixed-point rounding modes for financial precision.
public enum RoundingMode {
    HALF_EVEN = "HALF_EVEN",
    HALF_UP = "HALF_UP",
    FLOOR = "FLOOR",
    CEILING = "CEILING",
    TRUNCATE = "TRUNCATE"
}

# Immutable high-precision financial decimal quantity.
#
# + value - Underlying exact decimal value
# + scale - Explicit decimal scaling precision (default 4 for banking)
public type ScaledDecimal record {|
    decimal value;
    int scale = 4;
|};

# Creates a ScaledDecimal from a numeric string.
#
# + raw - Numerical string representation
# + scale - Explicit decimal precision scale
# + return - ScaledDecimal instance or FixedPointArithmeticError on syntax error
public function fromString(string raw, int scale = 4) returns ScaledDecimal|types:FixedPointArithmeticError {
    string trimmed = raw.trim();
    if trimmed.length() == 0 {
        return error types:FixedPointArithmeticError("Empty numerical string input");
    }
    decimal|error parsed = decimal:fromString(trimmed);
    if parsed is error {
        return error types:FixedPointArithmeticError("Invalid numerical format: " + trimmed);
    }
    return {
        value: parsed,
        scale: scale
    };
}

# Creates a ScaledDecimal from an integer amount of minor currency units (e.g. cents).
#
# + minorUnits - Quantity in smallest currency denomination (e.g. cents)
# + minorScale - Minor unit power of ten (e.g. 2 for USD cents, 0 for JPY, 3 for BHD)
# + return - ScaledDecimal representation
public function fromMinorUnits(int minorUnits, int minorScale = 2) returns ScaledDecimal {
    decimal divisor = 1.0d;
    int idx = 0;
    while idx < minorScale {
        divisor = divisor * 10.0d;
        idx = idx + 1;
    }
    decimal decVal = <decimal>minorUnits / divisor;
    return {
        value: decVal,
        scale: minorScale
    };
}

# Converts a ScaledDecimal into an integer quantity of minor currency units.
#
# + dec - ScaledDecimal input
# + minorScale - Minor unit power of ten
# + return - Integer minor currency units rounded half-even
public function toMinorUnits(ScaledDecimal dec, int minorScale = 2) returns int {
    decimal multiplier = 1.0d;
    int idx = 0;
    while idx < minorScale {
        multiplier = multiplier * 10.0d;
        idx = idx + 1;
    }
    decimal scaled = dec.value * multiplier;
    return <int>scaled.round();
}

# Adds two ScaledDecimal values with precision alignment.
#
# + a - First operand
# + b - Second operand
# + return - Resulting ScaledDecimal with maximum scale
public function add(ScaledDecimal a, ScaledDecimal b) returns ScaledDecimal {
    int maxScale = a.scale > b.scale ? a.scale : b.scale;
    return {
        value: a.value + b.value,
        scale: maxScale
    };
}

# Subtracts operand b from operand a.
#
# + a - Minuend
# + b - Subtrahend
# + return - Resulting ScaledDecimal difference
public function sub(ScaledDecimal a, ScaledDecimal b) returns ScaledDecimal {
    int maxScale = a.scale > b.scale ? a.scale : b.scale;
    return {
        value: a.value - b.value,
        scale: maxScale
    };
}

# Multiplies two ScaledDecimal values.
#
# + a - Multiplicand
# + b - Multiplier
# + return - Resulting product
public function mul(ScaledDecimal a, ScaledDecimal b) returns ScaledDecimal {
    int newScale = a.scale + b.scale;
    return {
        value: a.value * b.value,
        scale: newScale
    };
}

# Divides operand a by operand b with explicit rounding and scale cap.
#
# + a - Numerator
# + b - Denominator
# + targetScale - Desired quotient precision scale
# + return - Quotient ScaledDecimal or error on zero divisor
public function div(ScaledDecimal a, ScaledDecimal b, int targetScale = 4) returns ScaledDecimal|types:FixedPointArithmeticError {
    if b.value == 0.0d {
        return error types:FixedPointArithmeticError("Division by zero in financial decimal calculation");
    }
    decimal quotient = a.value / b.value;
    return {
        value: quotient,
        scale: targetScale
    };
}

# Compares two ScaledDecimals.
#
# + a - First operand
# + b - Second operand
# + return - -1 if a < b, 0 if a == b, 1 if a > b
public function compare(ScaledDecimal a, ScaledDecimal b) returns int {
    if a.value < b.value {
        return -1;
    } else if a.value > b.value {
        return 1;
    }
    return 0;
}

# Returns true if the ScaledDecimal equals zero.
#
# + dec - Operand to evaluate
# + return - Boolean indication
public function isZero(ScaledDecimal dec) returns boolean {
    return dec.value == 0.0d;
}

# Returns true if operand is strictly positive.
#
# + dec - Operand to evaluate
# + return - Boolean indication
public function isPositive(ScaledDecimal dec) returns boolean {
    return dec.value > 0.0d;
}

# Returns true if operand is strictly negative.
#
# + dec - Operand to evaluate
# + return - Boolean indication
public function isNegative(ScaledDecimal dec) returns boolean {
    return dec.value < 0.0d;
}

# Returns absolute value of the operand.
#
# + dec - Input operand
# + return - Non-negative ScaledDecimal
public function abs(ScaledDecimal dec) returns ScaledDecimal {
    return {
        value: dec.value < 0.0d ? -dec.value : dec.value,
        scale: dec.scale
    };
}

# Saturating subtraction preventing value from descending below zero.
#
# + a - Available balance
# + b - Requested debit
# + return - a - b or zero if b > a
public function saturatingSub(ScaledDecimal a, ScaledDecimal b) returns ScaledDecimal {
    if b.value >= a.value {
        return { value: 0.0d, scale: a.scale };
    }
    return sub(a, b);
}

# Formats a ScaledDecimal to standard financial string representation.
#
# + dec - Input operand
# + decimalPlaces - Number of fractional decimal digits to format
# + return - Formatted numerical string
public function formatFinancial(ScaledDecimal dec, int decimalPlaces = 2) returns string {
    decimal val = dec.value;
    boolean neg = val < 0.0d;
    if neg {
        val = -val;
    }

    // Multiply by factor to round fractional digits
    decimal factor = 1.0d;
    int idx = 0;
    while idx < decimalPlaces {
        factor = factor * 10.0d;
        idx = idx + 1;
    }

    decimal rounded = (val * factor).round();
    int wholeInt = <int>((rounded / factor).floor());
    int fracInt = <int>(rounded % factor);

    string fracStr = fracInt.toString();
    while fracStr.length() < decimalPlaces {
        fracStr = "0" + fracStr;
    }

    string res = wholeInt.toString();
    if decimalPlaces > 0 {
        res = res + "." + fracStr;
    }
    if neg && (wholeInt != 0 || fracInt != 0) {
        res = "-" + res;
    }
    return res;
}

# Verifies that an array of debit and credit amounts sums exactly to zero.
#
# + debits - Array of debit amounts
# + credits - Array of credit amounts
# + return - True if sum(debits) equals sum(credits)
public function verifyBalance(ScaledDecimal[] debits, ScaledDecimal[] credits) returns boolean {
    decimal sumDebits = 0.0d;
    foreach ScaledDecimal d in debits {
        sumDebits = sumDebits + d.value;
    }

    decimal sumCredits = 0.0d;
    foreach ScaledDecimal c in credits {
        sumCredits = sumCredits + c.value;
    }

    return sumDebits == sumCredits;
}
