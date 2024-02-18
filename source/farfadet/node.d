/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.node;

import std.conv : to;
import std.exception : enforce;
import std.format : format;

import farfadet.error;
import farfadet.token;
import farfadet.tokenizer;
import farfadet.value;

final class Farfadet {
    private {
        string _name;
        Value[] _values;
        Farfadet[] _nodes;
    }

    @property {
        string name() const {
            return _name;
        }

        const(Farfadet[]) nodes() const {
            return _nodes;
        }
    }

    T get(T)(size_t index) const {
        enforce!FarfadetException(index < _values.length,
            format!"invalid index %d out of %d argument(s) available"(index, _values.length));
        return _values[index].get!T();
    }

    this(string text) {
        Tokenizer tokenizer = new Tokenizer(text);

        while (!tokenizer.isEndToken()) {
            Farfadet node = new Farfadet(tokenizer);
            _nodes ~= node;
        }
    }

    private this(Tokenizer tokenizer) {
        Token token = tokenizer.getToken();
        tokenizer.check(token.type == Token.Type.key,
            format!"missing key, found `%s` instead"(token.toString()), token);

        _name = token.strValue;
        tokenizer.advanceToken();

        while (!tokenizer.isEndToken()) {
            token = tokenizer.getToken();
            switch (token.type) with (Token.Type) {
            case openBlock:
                _parseBlock(tokenizer);
                return;
            case key:
                return;
            default:
                _values ~= _parseParameter(tokenizer);
                break;
            }
        }
    }

    private void _parseBlock(Tokenizer tokenizer) {
        tokenizer.advanceToken();
        for (;;) {
            Token token = tokenizer.getToken();
            if (token.type == Token.Type.closeBlock) {
                tokenizer.advanceToken();
                return;
            }

            Farfadet node = new Farfadet(tokenizer);
            _nodes ~= node;
        }
    }

    private Value _parseParameter(Tokenizer tokenizer) {
        Token token = tokenizer.getToken();
        final switch (token.type) with (Token.Type) {
        case key:
            throw new FarfadetException("unexpected key in place of an argument");
        case int_:
            tokenizer.advanceToken();
            return Value(token.intValue);
        case uint_:
            tokenizer.advanceToken();
            return Value(token.uintValue);
        case char_:
            tokenizer.advanceToken();
            return Value(token.charValue);
        case float_:
            tokenizer.advanceToken();
            return Value(token.floatValue);
        case string_:
            tokenizer.advanceToken();
            return Value(token.strValue);
        case bool_:
            tokenizer.advanceToken();
            return Value(token.boolValue);
        case openBlock:
            throw new FarfadetException("unexpected `{` in place of an argument");
        case closeBlock:
            throw new FarfadetException("unexpected `}` in place of an argument");
        case openArray:
            Value[] array;
            tokenizer.advanceToken();
            for (;;) {
                token = tokenizer.getToken();
                if (token.type == Token.Type.closeArray) {
                    tokenizer.advanceToken();
                    break;
                }
                array ~= _parseParameter(tokenizer);
            }
            return Value(array);
        case closeArray:
            throw new FarfadetException("unexpected `]` in place of an argument");
        }
    }
}
