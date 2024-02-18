/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.value;

import std.exception : enforce;
import std.traits;

import farfadet.error;

package struct Value {
    enum Type {
        uint_,
        int_,
        char_,
        float_,
        bool_,
        string_,
        array_
    }

    private {
        Type _type;

        union {
            ulong _uint;
            long _int;
            dchar _char;
            double _float;
            bool _bool;
            string _string;
            Value[] _array;
        }
    }

    @property {
        /// Type de valeur contenue
        Type type() const {
            return _type;
        }

        /// Ditto
        private Type type(Type type_) {
            return _type = type_;
        }
    }

    this(ulong value) {
        _type = Type.uint_;
        _uint = value;
    }

    this(long value) {
        _type = Type.int_;
        _int = value;
    }

    this(dchar value) {
        _type = Type.char_;
        _char = value;
    }

    this(double value) {
        _type = Type.float_;
        _float = value;
    }

    this(bool value) {
        _type = Type.bool_;
        _bool = value;
    }

    this(string value) {
        _type = Type.string_;
        _string = value;
    }

    this(Value[] values) {
        _type = Type.array_;
        _array = values;
    }

    T get(T)() const {
        static if (isSomeString!T) {
            enforce!FarfadetException(_type == Type.string_, "the value is not a string");
            return to!T(_string);
        }
        else static if (is(T == U[], U)) {
            T result;
            foreach (value; _array) {
                result ~= value.get!U();
            }
            return result;
        }
        else static if (isSomeChar!T) {
            enforce!FarfadetException(_type == Type.char_, "the value is not a character");
            return to!T(_char);
        }
        else static if (is(T == bool)) {
            enforce!FarfadetException(_type == Type.bool_, "the value is not boolean");
            return _bool;
        }
        else static if (__traits(isIntegral, T)) {
            static if (__traits(isUnsigned, T)) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "the value is too big");
                    }
                    return cast(T) _uint;
                case int_:
                    enforce!FarfadetException(_int >= 0, "the value is negative");
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "the value is too big");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("the value is not an unsigned integral number");
                }
            }
            else static if (isSigned!T) {
                switch (_type) with (Type) {
                case uint_:
                    static if (T.sizeof < ulong.sizeof) {
                        enforce!FarfadetException(_uint < T.max, "the value is too big");
                    }
                    static if (T.sizeof == ulong.sizeof) {
                        enforce!FarfadetException(_uint & (1uL << 63), "the value is too big");
                    }
                    return cast(T) _uint;
                case int_:
                    static if (T.sizeof < long.sizeof) {
                        enforce!FarfadetException(_int < T.max, "the value is too big");
                    }
                    return cast(T) _int;
                default:
                    throw new FarfadetException("the value is not an signed integral number");
                }
            }
        }
        else static if (__traits(isFloating, T)) {
            switch (_type) with (Type) {
            case uint_:
                return cast(T) _uint;
            case int_:
                return cast(T) _int;
            case float_:
                return cast(T) _float;
            default:
                throw new FarfadetException("the value is not a floating point number");
            }
        }
        else {
            static assert(false, "unsupported type `" ~ T.stringof ~ "`");
        }
    }
}
