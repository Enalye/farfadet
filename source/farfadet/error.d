/** 
 * Droits d’auteur: Enalye
 * Licence: Zlib
 * Auteur: Enalye
 */
module farfadet.error;

import std.exception;

/// Décrit une erreur de farfadet
class FarfadetException : Exception {
    mixin basicExceptionCtors;
}
