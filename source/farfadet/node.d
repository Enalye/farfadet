/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.node;

import std.conv : to;
import std.exception : enforce;

import farfadet.error;
import farfadet.token;
import farfadet.tokenizer;
import farfadet.value;

final class Farfadet {
    private {
        string _name;
        FarfadetValue[] _values;
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
        enforce!FarfadetException(index < _values.length, "index invalide");
        return _values[index].get!T();
    }

    this(string text) {
        FarfadetParser parser = new FarfadetParser(text);

        while (!parser.isEndToken()) {
            Farfadet node = new Farfadet(parser);
            _nodes ~= node;
        }
    }

    private this(FarfadetParser parser) {
        FarfadetToken token = parser.getToken();
        enforce!FarfadetException(token.type == FarfadetToken.Type.key,
            "missing key, found `" ~ to!string(token.type) ~ "` instead");

        _name = token.strValue;
        parser.advanceToken();

        while (!parser.isEndToken()) {
            token = parser.getToken();
            switch (token.type) with (FarfadetToken.Type) {
            case openBlock:
                _parseBlock(parser);
                return;
            case key:
                return;
            default:
                _values ~= _parseParameter(parser);
                break;
            }
        }
    }

    private void _parseBlock(FarfadetParser parser) {
        parser.advanceToken();
        for (;;) {
            FarfadetToken token = parser.getToken();
            if (token.type == FarfadetToken.Type.closeBlock) {
                parser.advanceToken();
                return;
            }

            Farfadet node = new Farfadet(parser);
            _nodes ~= node;
        }
    }

    private FarfadetValue _parseParameter(FarfadetParser parser) {
        FarfadetToken token = parser.getToken();
        final switch (token.type) with (FarfadetToken.Type) {
        case key:
            throw new FarfadetException("key");
        case int_:
            parser.advanceToken();
            return FarfadetValue(token.intValue);
        case uint_:
            parser.advanceToken();
            return FarfadetValue(token.uintValue);
        case char_:
            parser.advanceToken();
            return FarfadetValue(token.charValue);
        case float_:
            parser.advanceToken();
            return FarfadetValue(token.floatValue);
        case bool_:
            parser.advanceToken();
            return FarfadetValue(token.boolValue);
        case string_:
            parser.advanceToken();
            return FarfadetValue(token.strValue);
        case true_:
            parser.advanceToken();
            return FarfadetValue(true);
        case false_:
            parser.advanceToken();
            return FarfadetValue(false);
        case openBlock:
            throw new FarfadetException("openBlock");
        case closeBlock:
            throw new FarfadetException("closeBlock");
        case openArray:
            FarfadetValue[] array;
            parser.advanceToken();
            for (;;) {
                token = parser.getToken();
                if (token.type == FarfadetToken.Type.closeArray) {
                    parser.advanceToken();
                    break;
                }
                array ~= _parseParameter(parser);
            }
            return FarfadetValue(array);
        case closeArray:
            throw new FarfadetException("closeArray");
        }
    }
}
