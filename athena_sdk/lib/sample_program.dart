List<int> f(List<int> x) {
  final List<int> res = [];
  for (int i = 0; i < x.length; i++) {
    if (x[i] < 10) {
      res.add(x[i]);
    }
  }
  return res;
}
