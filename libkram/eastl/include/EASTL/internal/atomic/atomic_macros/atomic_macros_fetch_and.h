/////////////////////////////////////////////////////////////////////////////////
// Copyright (c) Electronic Arts Inc. All rights reserved.
/////////////////////////////////////////////////////////////////////////////////


#pragma once

/////////////////////////////////////////////////////////////////////////////////
//
// void EASTL_ATOMIC_FETCH_AND_*_N(type, type ret, type * ptr, type val)
//
#define EASTL_ATOMIC_FETCH_AND_RELAXED_8(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELAXED_8)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQUIRE_8(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQUIRE_8)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_RELEASE_8(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELEASE_8)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQ_REL_8(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQ_REL_8)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_SEQ_CST_8(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_SEQ_CST_8)(type, ret, ptr, val)


#define EASTL_ATOMIC_FETCH_AND_RELAXED_16(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELAXED_16)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQUIRE_16(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQUIRE_16)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_RELEASE_16(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELEASE_16)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQ_REL_16(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQ_REL_16)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_SEQ_CST_16(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_SEQ_CST_16)(type, ret, ptr, val)


#define EASTL_ATOMIC_FETCH_AND_RELAXED_32(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELAXED_32)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQUIRE_32(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQUIRE_32)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_RELEASE_32(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELEASE_32)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQ_REL_32(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQ_REL_32)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_SEQ_CST_32(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_SEQ_CST_32)(type, ret, ptr, val)


#define EASTL_ATOMIC_FETCH_AND_RELAXED_64(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELAXED_64)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQUIRE_64(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQUIRE_64)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_RELEASE_64(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELEASE_64)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQ_REL_64(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQ_REL_64)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_SEQ_CST_64(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_SEQ_CST_64)(type, ret, ptr, val)


#define EASTL_ATOMIC_FETCH_AND_RELAXED_128(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELAXED_128)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQUIRE_128(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQUIRE_128)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_RELEASE_128(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_RELEASE_128)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_ACQ_REL_128(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_ACQ_REL_128)(type, ret, ptr, val)

#define EASTL_ATOMIC_FETCH_AND_SEQ_CST_128(type, ret, ptr, val)			\
	EASTL_ATOMIC_CHOOSE_OP_IMPL(ATOMIC_FETCH_AND_SEQ_CST_128)(type, ret, ptr, val)

