module Vagrant
  class Action
    # Action builder which provides a nice DSL for building up
    # a middleware sequence for Vagrant actions. This code is based
    # heavily off of `Rack::Builder` and `ActionDispatch::MiddlewareStack`
    # in Rack and Rails, respectively.
    #
    # Usage
    #
    # Building an action sequence is very easy:
    #
    #     app = Vagrant::Action::Builder.new do
    #       use MiddlewareA
    #       use MiddlewareB
    #     end
    #
    #     Vagrant::Action.run(app)
    #
    class Builder
      # Initializes the builder. An optional block can be passed which
      # will be evaluated in the context of the instance.
      def initialize(&block)
        instance_eval(&block) if block_given?
      end

      # Returns the current stack of middlewares. You probably won't
      # need to use this directly, and its recommended that you don't.
      #
      # @return [Array]
      def stack
        @stack ||= []
      end

      # Adds a middleware class to the middleware stack. Any additional
      # args and a block, if given, are saved and passed to the initializer
      # of the middleware.
      #
      # @param [Class] middleware The middleware class
      def use(middleware, *args, &block)
        if middleware.kind_of?(Builder)
          # Merge in the other builder's stack into our own
          self.stack.concat(middleware.stack)
        else
          self.stack << [middleware, args, block]
        end
      end

      # Converts the builder stack to a runnable action sequence.
      #
      # @param [Vagrant::Action::Environment] env The action environment
      # @return [Object] A callable object
      def to_app(env)
        # Prepend the error halt task so errneous environments are halted
        # before the chain even begins.
        items = stack.dup.unshift([ErrorHalt, [], nil])

        # Convert each middleware into a lambda which takes the next
        # middleware.
        items = items.collect do |item|
          klass, args, block = item
          lambda { |app| klass.new(app, env, *args, &block) }
        end

        # Append the final step and convert into flattened call chain.
        items << lambda { |env| }
        items[0...-1].reverse.inject(items.last) { |a,e| e.call(a) }
      end

      # Runs the builder stack with the given environment.
      def call(env)
        to_app(env).call(env)
      end
    end
  end
end