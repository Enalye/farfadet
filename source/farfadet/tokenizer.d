/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.tokenizer;

import std.string, std.array, std.math;
import std.conv : to, ConvOverflowException;
import std.exception;

import farfadet.error;
import farfadet.token;

package final class Tokenizer {
    private {
        Token[] _tokens;
        dstring[] _lines;
        dstring _text;
        size_t _line, _current, _positionOfLine;
        string _filePath;
        size_t _currentToken;
    }

    @property {
        size_t line() const {
            return _line;
        }

        size_t current() const {
            return _current;
        }

        size_t positionOfLine() const {
            return _positionOfLine;
        }
    }

    this(string text) {
        _filePath = "";
        _text = to!dstring(text);
        _line = 0u;
        _current = 0u;
        _positionOfLine = 0u;
        _lines = split(_text, "\n");
        _tokenize();
    }

    /// Renvoie le caractère présent à la position du curseur.
    private dchar _getCurrent(sizediff_t offset = 0) {
        const ptrdiff_t position = (cast(ptrdiff_t) _current) + offset;
        _check(position >= 0 && position < _text.length, "fin de fichier inopiné");
        return _text[position];
    }

    private void _tokenize() {
        // On ignore les espaces/commentaires situés au début
        _advance(true);

        if (_current >= _text.length) {
            return;
        }

        int blockLevel, arrayLevel;
        int[] arrayLevels;

        do {
            if (_current >= _text.length)
                break;

            switch (_getCurrent()) {
            case '.':
            case '-':
            case '+':
            case '0': .. case '9':
                _scanNumber();
                break;
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
            case '_':
                _scanKey();
                break;
            case '\"':
                _scanString();
                break;
            case '\'':
                _scanChar();
                break;
            case '{':
                Token token = Token(_line, _current, _positionOfLine);
                token.type = Token.Type.openBlock;
                _tokens ~= token;
                blockLevel++;

                arrayLevels ~= arrayLevel;
                arrayLevel = 0;
                break;
            case '}':
                Token token = Token(_line, _current, _positionOfLine);
                token.type = Token.Type.closeBlock;
                _tokens ~= token;
                blockLevel--;

                _check(blockLevel >= 0,
                    "les accolades ouvrantes et fermantes ne correspondent pas");

                if (arrayLevels.length) {
                    arrayLevel = arrayLevels[$ - 1];
                    arrayLevels.length--;
                }
                else {
                    arrayLevel = 0;
                }
                break;
            case '[':
                Token token = Token(_line, _current, _positionOfLine);
                token.type = Token.Type.openArray;
                _tokens ~= token;
                arrayLevel++;
                break;
            case ']':
                Token token = Token(_line, _current, _positionOfLine);
                token.type = Token.Type.closeArray;
                _tokens ~= token;
                arrayLevel--;

                _check(arrayLevel >= 0, "les crochets ouvrants et fermants ne correspondent pas");
                break;
            default:
                break;
            }
        }
        while (_advance());
    }

    /// Avance le curseur tout en ignorant les espaces et les commentaires.
    private bool _advance(bool startFromCurrent = false) {
        if (!startFromCurrent)
            _current++;

        if (_current >= _text.length)
            return false;

        dchar symbol = _text[_current];

        whileLoop: while (symbol <= 0x20 || symbol == '/' || symbol == '#') {
            if (_current >= _text.length)
                return false;

            symbol = _text[_current];

            if (symbol == '\n') {
                _positionOfLine = _current;
                _line++;
            }
            else if (symbol == '/') {
                if ((_current + 1) >= _text.length)
                    return false;

                switch (_text[_current + 1]) {
                case '/':
                    do {
                        if (_current >= _text.length)
                            return false;
                        _current++;
                    }
                    while (_current < _text.length && _text[_current] != '\n');
                    _positionOfLine = _current;
                    _line++;
                    break;
                case '*':
                    _advance();
                    _advance();
                    int commentScope = 0;
                    for (;;) {
                        if ((_current + 1) >= _text.length) {
                            _current++;
                            return false;
                        }

                        if (_text[_current] == '\n') {
                            _positionOfLine = _current;
                            _line++;
                        }
                        if (_text[_current] == '/' && _text[_current + 1] == '*') {
                            commentScope++;
                        }
                        else if (_text[_current] == '*' && _text[_current + 1] == '/') {
                            if (_current > 0 && _text[_current - 1] == '/') {
                                // On ignore
                            }
                            else if (commentScope == 0) {
                                _current++;
                                break;
                            }
                            else {
                                commentScope--;
                            }
                        }
                        _current++;
                    }
                    break;
                default:
                    break whileLoop;
                }
            }
            _current++;

            if (_current >= _text.length)
                return false;

            symbol = _text[_current];
        }
        return true;
    }

    /**
	Analyse un nombre littéral. \
	Les tirets du bas `_` sont ignorés à l’intérieur d’un nombre.
    - Un entier hexadécimal commence par 0x ou 0X.
    - Un entier octal commence par 0o ou 0o.
    - Un entier binaire commence par 0b ou 0b.
    - Un nombre flottant peut commencer par un point ou avoir un point au milieu mais pas finir par un point.
	*/
    private void _scanNumber() {
        Token token = Token(_line, _current, _positionOfLine);

        bool isStart = true;
        bool isPrefix, isMaybeFloat, isFloat;
        bool isBinary, isOctal, isHexadecimal;
        string buffer;
        bool isNegative = false;

        if (_getCurrent() == '+') {
            _advance();
            isNegative = false;
        }
        else if (_getCurrent() == '-') {
            _advance();
            isNegative = true;
        }

        for (;;) {
            dchar symbol = _getCurrent();

            if (isBinary) {
                if (symbol == '0' || symbol == '1') {
                    buffer ~= symbol;
                }
                else if (symbol == '_') {
                    // On ne fait rien, c’est purement visuel (par ex: 0b1111_1111)
                }
                else {
                    if (_current)
                        _current--;
                    break;
                }
            }
            else if (isOctal) {
                if (symbol >= '0' && symbol <= '7') {
                    buffer ~= symbol;
                }
                else if (symbol == '_') {
                    // On ne fait rien, c’est purement visuel (par ex: 0o7_77)
                }
                else {
                    if (_current)
                        _current--;
                    break;
                }
            }
            else if (isHexadecimal) {
                if ((symbol >= '0' && symbol <= '9') || (symbol >= 'a' &&
                        symbol <= 'f') || (symbol >= 'A' && symbol <= 'F')) {
                    buffer ~= symbol;
                }
                else if (symbol == '_') {
                    // On ne fait rien, c’est purement visuel (par ex: 0xff_ff)
                }
                else {
                    if (_current)
                        _current--;
                    break;
                }
            }
            else if (isPrefix && (symbol == 'b' || symbol == 'B')) {
                isPrefix = false;
                isBinary = true;
                buffer.length = 0;
            }
            else if (isPrefix && (symbol == 'o' || symbol == 'O')) {
                isPrefix = false;
                isOctal = true;
                buffer.length = 0;
            }
            else if (isPrefix && (symbol == 'x' || symbol == 'X')) {
                isPrefix = false;
                isHexadecimal = true;
                buffer.length = 0;
            }
            else if (symbol >= '0' && symbol <= '9') {
                if (isStart && symbol == '0') {
                    isPrefix = true;
                }
                else if (isMaybeFloat) {
                    buffer ~= '.';
                    isMaybeFloat = false;
                    isFloat = true;
                }

                buffer ~= symbol;
            }
            else if (symbol == '_') {
                // On ne fait rien, c’est purement visuel (par ex: 1_000_000)
            }
            else if (symbol == '.') {
                if (isMaybeFloat) {
                    _current -= 2;
                    break;
                }
                if (isFloat) {
                    _current--;
                    break;
                }
                isMaybeFloat = true;
            }
            else {
                if (_current)
                    _current--;

                if (isMaybeFloat)
                    _current--;
                break;
            }

            _current++;
            isStart = false;

            if (_current >= _text.length)
                break;
        }

        if (!buffer.length && !isFloat) {
            _check(false, "nombre vide");
        }

        try {
            if (isFloat) {
                token.type = Token.Type.float_;
                token.floatValue = to!double(buffer);
                if (isNegative)
                    token.floatValue = -token.floatValue;
            }
            else {
                uint radix = 10;
                if (isBinary)
                    radix = 2;
                else if (isOctal)
                    radix = 8;
                else if (isHexadecimal)
                    radix = 16;

                if (isNegative) {
                    token.type = Token.Type.int_;
                    token.intValue = -to!long(buffer, radix);
                }
                else {
                    const ulong value = to!ulong(buffer, radix);
                    if (value & (1uL << 63)) {
                        token.type = Token.Type.uint_;
                        token.uintValue = value;
                    }
                    else {
                        token.type = Token.Type.int_;
                        token.intValue = value;
                    }
                }
            }
        }
        catch (ConvOverflowException) {
            _check(false, "nombre trop grand");
        }
        _tokens ~= token;
    }

    /// Analyse une séquence d’échappement
    private dchar _scanEscapeCharacter(ref uint textLength) {
        dchar symbol;
        textLength = 1;

        // Pour la gestion d’erreur
        Token token = Token(_line, _current, _positionOfLine);

        if (_getCurrent() != '\\') {
            symbol = _getCurrent();
            _current++;
            return symbol;
        }
        _current++;
        textLength = 2;

        switch (_getCurrent()) {
        case '\'':
            symbol = '\'';
            break;
        case '\\':
            symbol = '\\';
            break;
        case '?':
            symbol = '\?';
            break;
        case '0':
            symbol = '\0';
            break;
        case 'a':
            symbol = '\a';
            break;
        case 'b':
            symbol = '\b';
            break;
        case 'f':
            symbol = '\f';
            break;
        case 'n':
            symbol = '\n';
            break;
        case 'r':
            symbol = '\r';
            break;
        case 't':
            symbol = '\t';
            break;
        case 'v':
            symbol = '\v';
            break;
        case 'u':
            _current++;
            textLength++;

            _check(_getCurrent() == '{',
                "symbole `{` manquant dans une séquence d’échappement unicode");
            _current++;
            textLength++;

            dstring buffer;
            while ((symbol = _getCurrent()) != '}') {
                if ((symbol >= '0' && symbol <= '9') || (symbol >= 'a' &&
                        symbol <= 'f') || (symbol >= 'A' && symbol <= 'F')) {
                    buffer ~= symbol;
                    textLength++;
                }
                else {
                    _check(false, "symbole inopiné dans une séquence d’échappement unicode");
                }
                _current++;
            }
            textLength++;

            try {
                const ulong value = to!ulong(buffer, 16);

                _check(value <= 0x10FFFF, "l’unicode doit valoir au plus 0x10FFFF");
                symbol = cast(dchar) value;
            }
            catch (ConvOverflowException e) {
                _check(false, "l’unicode doit valoir au plus 0x10FFFF");
            }

            break;
        default:
            symbol = _getCurrent();
            break;
        }
        _current++;

        return symbol;
    }

    /// Analyse un caractère délimité par des `'`.
    void _scanChar() {
        Token token = Token(_line, _current, _positionOfLine);
        token.type = Token.Type.char_;
        uint textLength = 0;

        _check(_getCurrent() == '\'', "symbole `'` manquant en début de caractère");
        _current++;
        textLength++;

        dchar ch = _getCurrent();

        if (ch == '\\') {
            ch = _scanEscapeCharacter(textLength);
        }
        else {
            _current++;
            textLength++;
        }

        textLength++;
        token.charValue = ch;
        _tokens ~= token;

        _check(_getCurrent() == '\'', "symbole `'` manquant en fin de caractère");
    }

    /// Analyse une chaîne de caractères délimité par des `"`.
    private void _scanString() {
        Token token = Token(_line, _current, _positionOfLine);
        token.type = Token.Type.string_;
        uint textLength = 0;

        _check(_getCurrent() == '\"', "symbole `\"` manquant en début de texte");
        _current++;
        textLength++;

        string buffer;
        for (;;) {
            _check(_current < _text.length, "symbole `\"` manquant en fin du texte");
            const dchar symbol = _getCurrent();

            if (symbol == '\n') {
                _positionOfLine = _current;
                _line++;

                buffer ~= _getCurrent();
                _current++;
                textLength++;
            }
            else if (symbol == '\"')
                break;
            else if (symbol == '\\')
                buffer ~= _scanEscapeCharacter(textLength);
            else {
                buffer ~= _getCurrent();
                _current++;
                textLength++;
            }
        }
        textLength++;

        token.strValue = buffer;
        _tokens ~= token;
    }

    /// Analyse une clé.
    private void _scanKey() {
        dstring buffer;
        for (;;) {
            if (_current >= _text.length)
                break;

            const dchar symbol = _getCurrent();
            if (!isKeyCharValid(symbol))
                break;

            buffer ~= symbol;
            _current++;
        }
        _current--;

        Token token = Token(_line, _current, _positionOfLine);

        switch (buffer) {
        case "true"d:
            token.type = Token.Type.bool_;
            token.boolValue = true;
            break;
        case "false"d:
            token.type = Token.Type.bool_;
            token.boolValue = false;
            break;
        default:
            token.type = Token.Type.key;
            token.strValue = to!string(buffer);
            break;
        }

        _tokens ~= token;
    }

    private void _check(bool value, string msg, string dfile = __FILE__, size_t dline = __LINE__) {
        if (value)
            return;
        throw new FarfadetSyntaxException(msg, _line + 1u, _current - _positionOfLine, dfile, dline);
    }

    package void check(bool value, string msg, string dfile = __FILE__, size_t dline = __LINE__) {
        if (value)
            return;
        Token token = getToken();
        throw new FarfadetSyntaxException(msg, token.line(), token.column(), dfile, dline);
    }

    /// Renvoie le jeton de la position actuelle
    Token getToken(sizediff_t offset = 0) {
        const ptrdiff_t position = (cast(ptrdiff_t) _currentToken) + offset;
        _check(position >= 0 && position < _tokens.length, "fin de fichier inopiné");
        return _tokens[position];
    }

    /// Vérifie la fin de la séquence
    bool isEndToken(sizediff_t offset = 0) {
        return (_currentToken + offset) >= cast(size_t) _tokens.length;
    }

    /// Avance jusqu’au prochain jeton
    void advanceToken() {
        if (_currentToken < _tokens.length)
            _currentToken++;
    }
}

package bool isValidKey(string name) {
    if (name.length == 0)
        return false;

    if (name[0] >= '0' && name[0] <= '9')
        return false;

    foreach (symbol; name) {
        if (!isKeyCharValid(symbol))
            return false;
    }

    return true;
}

private bool isKeyCharValid(dchar symbol) {
    switch (symbol) {
    case 0: .. case '&':
    case '(': .. case ',':
    case '/':
    case ';': .. case '?':
    case '[': .. case '^':
    case '{': .. case 0x7F:
        return false;
    default:
        return true;
    }
}
