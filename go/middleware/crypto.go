package middleware

// crypto.go holds the SHA-256 hashing helper used by auth.go's RS256 verification.
// Separated to keep auth.go focused on JWT logic.

import (
	"crypto"
	"crypto/sha256"
)

// cryptoSHA256 is the crypto.Hash constant for SHA-256, used by rsa.VerifyPKCS1v15.
var cryptoSHA256 = crypto.SHA256

// sha256Hash returns the SHA-256 digest of data.
func sha256Hash(data []byte) []byte {
	h := sha256.Sum256(data)
	return h[:]
}
