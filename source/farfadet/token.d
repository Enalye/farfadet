/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.token;

package struct FarfadetToken {
    enum Type {
        key,
        int_,
        uint_,
        char_,
        float_,
        bool_,
        string_,
        true_,
        false_,
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
}
