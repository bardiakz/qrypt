// native/oqs_wrapper.h
#include "include/oqs.h"
#ifdef __cplusplus
extern "C" {
#endif

#include "include/oqs/oqs.h"

// Example: Declare one function to test
OQS_KEM* OQS_KEM_kyber_512_new(void);
void OQS_KEM_free(OQS_KEM* kem);

#ifdef __cplusplus
}
#endif
