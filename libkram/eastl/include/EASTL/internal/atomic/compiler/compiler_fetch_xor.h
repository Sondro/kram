/////////////////////////////////////////////////////////////////////////////////
// Copyright (c) Electronic Arts Inc. All rights reserved.
/////////////////////////////////////////////////////////////////////////////////


#pragma once


/////////////////////////////////////////////////////////////////////////////////
//
// void EASTL_COMPILER_ATOMIC_FETCH_XOR_*_N(type, type ret, type * ptr, type val)
//
#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_8)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_8_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_8_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_8)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_8_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_8_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_8)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_8_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_8_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_8)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_8_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_8_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_8)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_8_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_8_AVAILABLE 0
#endif


#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_16)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_16_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_16_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_16)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_16_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_16_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_16)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_16_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_16_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_16)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_16_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_16_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_16)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_16_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_16_AVAILABLE 0
#endif


#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_32)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_32_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_32_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_32)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_32_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_32_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_32)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_32_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_32_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_32)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_32_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_32_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_32)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_32_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_32_AVAILABLE 0
#endif


#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_64)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_64_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_64_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_64)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_64_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_64_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_64)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_64_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_64_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_64)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_64_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_64_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_64)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_64_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_64_AVAILABLE 0
#endif


#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_128)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_128_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELAXED_128_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_128)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_128_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQUIRE_128_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_128)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_128_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_RELEASE_128_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_128)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_128_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_ACQ_REL_128_AVAILABLE 0
#endif

#if defined(EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_128)
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_128_AVAILABLE 1
#else
	#define EASTL_COMPILER_ATOMIC_FETCH_XOR_SEQ_CST_128_AVAILABLE 0
#endif


