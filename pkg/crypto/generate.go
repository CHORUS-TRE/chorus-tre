package crypto

import (
	"crypto/rand"
	"math/big"
)

const (
	passwordCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;':\",<>/?~"
)

// GenerateRandomString generates a random string of the specified length
func GenerateRandomString(length int) (string, error) {
	randomCharacters := make([]byte, length)
	for i := 0; i < length; i++ {
		randomInt, err := rand.Int(rand.Reader, big.NewInt(int64(len(passwordCharacters))))
		if err != nil {
			return "", err
		}
		randomCharacters[i] = passwordCharacters[randomInt.Int64()]
	}

	return string(randomCharacters), nil
}
