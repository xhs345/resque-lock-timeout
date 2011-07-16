## 0.3.0 (2011-07-16)

* Ability to customize redis connection used for storing locks.
  (thanks Richie Vos =))
* Added Bundler `Gemfile`.
* Added abstract stub methods for callback methods:
  `lock_failed`, `lock_expired_before_release`

## 0.2.1 (2010-06-16)

* Relax gemspec dependancies.

## 0.2.0 (2010-05-05)

* Initial release as `resque-lock-timeout`, forked from Chris Wanstrath'
`resque-lock`.