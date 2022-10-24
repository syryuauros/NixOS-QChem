#!./result/bin/python3

import numpy as np
import matplotlib.pyplot as plt

xs = np.linspace (-2, 2, num =100)
plt.plot(xs , np.exp(-xs **2))
plt.show()
