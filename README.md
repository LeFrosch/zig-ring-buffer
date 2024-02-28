## Ring Buffer
More like a proof of concept. Creates an anonymous file and maps it to two contiguous memory regions. This makes writing to the buffer trivial and also transparent to operations like `@memcpy`.
