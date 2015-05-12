# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :the_model do
    name         { "the_model_#{rand(1000000)}" }
    description  "This is a description of the_model."
    vip          "Greetings, O superuser!"
    lock_version 0
  end
end
