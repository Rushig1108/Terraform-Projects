variable "instance_type"{
    description = "This define the instance type"
    type = string
    default = "t2.micro"   
}

variable "ami-id"{
    description = "This defines the AMI id for the instance"
    type = string
}