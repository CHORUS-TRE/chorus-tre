package crypto

import "testing"

func TestGenerateRandomString(t *testing.T) {
	randomString, err := GenerateRandomString(10)
	if err != nil {
		t.Fatal(err)
	}
	if len(randomString) != 10 {
		t.Fatalf("Expected length of random string to be 10, got %d", len(randomString))
	}
}
