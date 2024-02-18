/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.token;

import std.conv : to;

package struct Token {
    enum Type {
        key,
        int_,
        uint_,
        char_,
        float_,
        bool_,
        string_,
        openBlock,
        closeBlock,
        openArray,
        closeArray
    }

    Type type;

    union {
        /// Valeur entière de la constante.
        long intValue;

        /// Valeur entière non-signée de la constante.
        ulong uintValue;

        /// Valeur unicode de la constante.
        dchar charValue;

        /// Valeur flottante de la constante.
        double floatValue;

        /// Valeur booléenne de la constante.
        bool boolValue;

        /// Décrit soit une valeur constante comme `"bonjour"` ou un identificateur.
        string strValue;
    }

    private {
        /// Informations sur sa position en cas d’erreur
        size_t _line, _column;
    }

    @property {
        /// Sa ligne
        size_t line() const {
            return _line + 1; // Par convention, la première ligne commence à 1, et non 0.
        }
        /// Sa colonne
        size_t column() const {
            return _column;
        }
    }

    package this(size_t line, size_t current, size_t positionOfLine) {
        _line = line;
        _column = current - positionOfLine;
    }

    @disable this();

    string toString() const {
        final switch (type) with (Type) {
        case key:
            return strValue;
        case int_:
            return to!string(intValue);
        case uint_:
            return to!string(uintValue);
        case char_:
            return "'" ~ to!string(charValue) ~ "'";
        case float_:
            return to!string(floatValue);
        case bool_:
            return boolValue ? "true" : "false";
        case string_:
            return "\"" ~ strValue ~ "\"";
        case openBlock:
            return "{";
        case closeBlock:
            return "}";
        case openArray:
            return "[";
        case closeArray:
            return "]";
        }
    }
}
