/**
* @brief Formats a number into a compact string representation with suffixes.
*
* This function converts a numeric value into a human-readable string format,
* appending suffixes (e.g., k, M, B) for large numbers and ensuring a fixed number of decimal places.
*
* @param value The numeric value to format.
* @param dec The number of decimal places to retain (default is 3).
* @return A formatted string representing the number with a suffix.
*
* @note
* - Values larger than 999 are divided by powers of 1000 and assigned appropriate suffixes.
* - The function ensures the resulting string has at most `dec` significant digits.
*/
function string_number_formatted(value, dec=3) {
    var val2 = value; ///< Copy of the original value for modification.
    var ee = 0; ///< Exponent indicating the power of 1000 for suffix.

    /// Suffixes for large numbers.
    var suffix = ["", "k", "M", "B", "T", "Z"];

    /// Reduce the value by dividing by 1000 until it's less than 1000.
    while (val2 >= 1000) {
        ee++;
        val2 /= 1000;
    }

    var txt = string(val2); ///< Convert the reduced value to a string.

    /// Adjust the string to retain the desired number of significant digits.
    if (ee > 0) {
        if (string_length(txt) < dec + 1) {
            /// Pad with zeroes if the string is too short.
            while (string_length(txt) < dec + 1) {
                txt += "0";
            }
        } else if (string_char_at(txt, dec + 1) == ".") {
            /// Trim to `dec` digits if the next character is a decimal point.
            txt = string_copy(txt, 1, dec);
        } else {
            /// Trim to `dec + 1` digits otherwise.
            txt = string_copy(txt, 1, dec + 1);
        }
    }

    var ind = clamp(ee, 0, array_length(suffix) - 1); ///< Clamp suffix index to valid range.

    /// Return the formatted string with the appropriate suffix.
    return (txt + string(suffix[ind]));
}

