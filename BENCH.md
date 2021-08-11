# Benchmarks

Here we try to evaluate different metrics to see how efficient the cluster is and how it performs as opposed to a single card. We'll also try to have power metrics and component usage over time.

## Time execution over the number of cards used

The following graphs will tell us how adding one card at a time benefits the efficiency.
All the python scripts used can be found in the `horovod` directory and the model was here trained on the `mnist` databse.

### Pytorch

First with the pytorch library, the first bench was done with a **low number of epochs (3)** to see the impact on short execution time :

![Execution time vs number of cards](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/pytorch-3epochs.png)

> NB : The loss and accuracy data didn't change by changing the number of cards.

Then we increase the number of **epochs up to 15** which leads us to the following results :

![Execution time vs number of cards](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/pytorch-15epochs.png)

### Tensorflow2

Same story here, we first launched the example script with **300 steps** leading us to the following results :

![Execution time vs number of cards](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/tensorflow-300steps.png)

And then with **3000 steps** :

![Execution time vs number of cards](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/tensorflow-3000steps.png)

### Intermediate conclusion

With the previous graphs we can see that the execution time scales fairly well as the number of cards increases. There is a constant time between the real and ideal time which is probably due to the test lap and also the mpi communication as we'll see later on.

However, even though this isn't a direct comparison between the two librairies, we'll see later on that the usage of the components is rather interesting. But only a direct comparison with similar models written in both librairies would tell the whole story.

## Power and usage metrics

The following charts will tell us the whole story behind the libraries and how efficient the cluster is. For a more accurate comparison this should be compared to a computer running the same model.

### Idle

First let's look at the metrics at idle with only the `tegrastats` and some python scripts running :

![GPU usage at idle](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/idle_gpu_usage.png)

![CPU usage at idle](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/idle_cpu_usage.png)

![Power usage at idle](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/idle_power_usage.png)

### PyTorch

We'll first look at the gpu usage over the whole test period :

![GPU usage for Pytorch](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/pytorch_gpu_usage.png)

We can see that the usage is very spotty and doesn't even max out at any point in time meaning the performance can probably be better with a little tinkering of the code.

We then have the cpu usage :

![CPU usage for Pytorch](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/pytorch_cpu_usage.png)

Nothing much to say here although the CPU may be used a bit more than in the tensorflow model.

Finally we have the power usage :

![Power usage for Pytorch](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/pytorch_power_usage.png)

Since the GPU isn't used to its full capacity the power isn't as high as we can expect with an average of around 4 watts with most of it being consumed by the CPU.

### TensorFlow

We'll first look at the gpu usage over the whole test period :

![GPU usage for TensorFlow](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/tensorflow_gpu_usage.png)

We can see that the usage is relatively even over the time maxing out at 100%. The part where the usage is constant is where horovod wasn't involved since the model was running on a single card. Once horovod is used with more than a single card we can see that the usage moves around a bit but still maxes out.

We then have the cpu usage :

![CPU usage for TensorFlow](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/tensorflow_cpu_usage.png)

Here we see that the CPU isn't used as much as in the PyTorch example. The usage we see is due to the horovod communication as it doesn't appear in the 1 card use case.

Finally we have the power usage :

![Power usage for TensorFlow](https://raw.githubusercontent.com/mohamed-chamrouk/jetson-nano-clustering/master/sources/tensorflow_power_usage.png)

Here we see a totally different story compared to PyTorch. When a card is used alone its power is around 6.5w and when using horovod its power consumption is around 7w. Moreover the gpu uses more power than the cpu as expected.

## Conclusion

All in all here is a table summing up all the previously seen metrics :

| Library | Number of cards | GPU Usage | CPU Usage | Power usage |
|-|-|-|-|-|
|PyTorch|1|20-80%|50%|4W|
|PyTorch|8|30-90%|70%|36W|
|TensorFlow|1|100%|20%|6.5W|
|TensorFlow|8|100% (spotty)|50%|56W|