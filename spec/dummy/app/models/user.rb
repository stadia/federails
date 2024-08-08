class User < ApplicationRecord
  include Federails::Entity

  acts_as_federails_actor username_field: :id, name_field: :email

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
