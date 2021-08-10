# Benchmarks

Here we try to evaluate different metrics to see how efficient the cluster is and how it performs as opposed to a single card. We'll also try to have power metrics and component usage over time.

## Time execution over the number of cards used

The following graphs will tell us how adding one card at a time benefits the efficiency.

### Pytorch

First with the pytorch library, the first bench was done with a low number of epochs (3) to see the impact on short execution time :

![Execution time vs number of cards]()