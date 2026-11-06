// Unit tests for sequential_quicksort (Google Test).
// They FAIL until you implement src/sequential_quicksort.cpp -- that is expected.
//   make unit                              run all tests
//   ./bin/unit_tests --gtest_filter='*Sorted*'   run some of them
//
// Add your own tests here, e.g. for helper functions (partition, pivot
// choice) once you have them.
#include "common.hpp"
#include "quicksort.hpp"

#include <gtest/gtest.h>

#include <algorithm>
#include <chrono>
#include <climits>

namespace {

// Sorts `v` with sequential_quicksort and compares with std::sort.
void expect_sorts(std::vector<int> v) {
    std::vector<int> expected = v;
    std::sort(expected.begin(), expected.end());
    sequential_quicksort(v);
    EXPECT_EQ(v, expected);
}

}  // namespace

TEST(SequentialQuicksort, Empty) { expect_sorts({}); }

TEST(SequentialQuicksort, OneElement) { expect_sorts({42}); }

TEST(SequentialQuicksort, TwoElements) {
    expect_sorts({2, 1});
    expect_sorts({1, 2});
}

TEST(SequentialQuicksort, SmallHandWritten) { expect_sorts({5, 3, 9, 1, 3, 7, 0, 8, 2, 6}); }

TEST(SequentialQuicksort, Duplicates) { expect_sorts({3, 1, 3, 3, 2, 1, 3, 2, 2, 1, 3}); }

TEST(SequentialQuicksort, AllEqual) { expect_sorts(std::vector<int>(100000, 7)); }

TEST(SequentialQuicksort, NegativeAndExtremeValues) {
    expect_sorts({INT_MAX, INT_MIN, 0, -1, 1, INT_MAX, INT_MIN, -42});
}

TEST(SequentialQuicksort, AlreadySorted) {
    std::vector<int> v = random_input(100000, 3);
    std::sort(v.begin(), v.end());
    expect_sorts(v);
}

TEST(SequentialQuicksort, ReverseSorted) {
    std::vector<int> v = random_input(100000, 4);
    std::sort(v.rbegin(), v.rend());
    expect_sorts(v);
}

TEST(SequentialQuicksort, FewDistinctValues) {
    std::vector<int> v = random_input(100000, 5);
    for (int& x : v) x %= 4;
    expect_sorts(v);
}

// Random inputs of many sizes, against std::sort.
class RandomInput : public ::testing::TestWithParam<long> {};

TEST_P(RandomInput, MatchesStdSort) {
    for (unsigned seed : {1u, 2u, 3u}) expect_sorts(random_input(GetParam(), seed));
}

INSTANTIATE_TEST_SUITE_P(Sizes, RandomInput,
                         ::testing::Values(3L, 10L, 31L, 32L, 33L, 100L, 1000L, 65537L, 1000000L));

// A quadratic quicksort takes minutes on these; a good one takes milliseconds.
TEST(SequentialQuicksort, NotQuadraticOnSortedInput) {
    std::vector<int> v(2000000);
    for (std::size_t i = 0; i < v.size(); ++i) v[i] = static_cast<int>(i);
    const auto t0 = std::chrono::steady_clock::now();
    sequential_quicksort(v);
    const double s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    EXPECT_TRUE(std::is_sorted(v.begin(), v.end()));
    EXPECT_LT(s, 2.0) << "sorting 2M already-sorted ints took " << s << " s";
}
