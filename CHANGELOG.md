# [0.2.0](https://github.com/iloveitaly/hyper-focus/compare/v0.1.10...v0.2.0) (2023-05-18)


### Features

* adding description and schedule_only flags to config ([b8061f6](https://github.com/iloveitaly/hyper-focus/commit/b8061f6b291352787d04c3aef99f2cfd759037ba))
* increase task timeout to 10m ([ef2e175](https://github.com/iloveitaly/hyper-focus/commit/ef2e175b0cbe3f0976d5d415e7f975f3bcdc5e7f))
* return all schedule data ([a3eb3ee](https://github.com/iloveitaly/hyper-focus/commit/a3eb3ee257c31c824e79cf6d5af891547c7fe67c))



## [0.1.10](https://github.com/iloveitaly/hyper-focus/compare/v0.1.9...v0.1.10) (2023-04-19)



## [0.1.9](https://github.com/iloveitaly/hyper-focus/compare/v0.1.8...v0.1.9) (2023-04-19)


### Bug Fixes

* blocking urls when the viewed url is identical to a block_url entry ([a0ac50a](https://github.com/iloveitaly/hyper-focus/commit/a0ac50a50e43a465d19a64e2222b3032fcb4836e))
* update last wake time immediately when recieving notification ([0824128](https://github.com/iloveitaly/hyper-focus/commit/0824128736f655460d01bab29232fed407762d96))
* using different notification for unlock ([a675d87](https://github.com/iloveitaly/hyper-focus/commit/a675d873c746976e90e001ebf03d2f3fef09a07a))


### Features

* add accessibility permissions dialog and open command ([a5cf5ff](https://github.com/iloveitaly/hyper-focus/commit/a5cf5ff1ffe86e19e4e1fa9c65924124c86c7854))
* add support for `start_script` in config ([63e776e](https://github.com/iloveitaly/hyper-focus/commit/63e776ea53fefb7ec92259ae26dceb4df4378508))
* adding idle check which treats like idle periods as a wake from sleep ([ca1954b](https://github.com/iloveitaly/hyper-focus/commit/ca1954b8f9fec54aacc8a642fdbd743fa7ef1dc6))
* lock execution types ([e26b94d](https://github.com/iloveitaly/hyper-focus/commit/e26b94d986b2b09413b3f39a9193f94de8b4d6c4))
* support reloading configuration in memory ([0b2d409](https://github.com/iloveitaly/hyper-focus/commit/0b2d409cac11988a490811cabd96a52274fe261e))
* watch for login events and treat them as sleep wakes if a long time has passed and they cross a day boundary ([7085d9a](https://github.com/iloveitaly/hyper-focus/commit/7085d9a94ec167e2fb265d9abf2566bdd5719a20))



## [0.1.8](https://github.com/iloveitaly/hyper-focus/compare/v0.1.7...v0.1.8) (2023-02-22)


### Bug Fixes

* custom formatting for switching activity ([a7a1797](https://github.com/iloveitaly/hyper-focus/commit/a7a17971c04d45a37a41d2b2c6ec11499727d8f5))
* flush stdout on each log, respect non-info log levels ([6fe221a](https://github.com/iloveitaly/hyper-focus/commit/6fe221a9354c9bf82b7baa24dfb7b43226d03914))
* handle first wake even if there is no previous wake ([26650b8](https://github.com/iloveitaly/hyper-focus/commit/26650b82d0a3c7bade22da5ced62f018ee94a243))



## [0.1.7](https://github.com/iloveitaly/hyper-focus/compare/v0.1.6...v0.1.7) (2023-02-07)


### Bug Fixes

* add log when accessibility permissions do not exist ([3e15c6f](https://github.com/iloveitaly/hyper-focus/commit/3e15c6fb822f56b8dd2887695cdf8a0aaa7590c9))


### Features

* **sleepwatcher:** run command directly if it is executable ([73f2681](https://github.com/iloveitaly/hyper-focus/commit/73f26817d547762ac6c8cf1ad15dd7e61e55708e))



